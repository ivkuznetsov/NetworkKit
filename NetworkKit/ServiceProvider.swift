//
//  ServiceProvider.swift
//  NetworkKit
//
//  Created by Ilya Kuznetsov on 11/21/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import AFNetworking
import os.log

public typealias ProcessLogin = (Error?) -> ()
public typealias RequestProgress = (Double) -> ()

@objc open class ServiceProvider : AFHTTPSessionManager {
    
    public var responserKey: String?
    public var authorizationToken: String?
    @objc public var enabledLogging: Bool = true
    
    public var authFailedCode = HTTPStatusCodes.HTTP_UNAUTORIZED.rawValue
    private var loginProcess: ((@escaping ProcessLogin)->())?
    private var combiner = OperationCombiner()
    
    @objc public init(baseURL url: URL,
                        loginProcess: ((@escaping (Error?)->())->())?,
                        requestSerializer: AFHTTPRequestSerializer,
                        responseSerializer: AFHTTPResponseSerializer) {
        
        super.init(baseURL: url, sessionConfiguration: nil)
        self.loginProcess = loginProcess
        self.requestSerializer = requestSerializer
        self.responseSerializer = responseSerializer
    }
    
    @objc public convenience init(baseURL url: URL, loginProcess: ((@escaping ProcessLogin)->())?) {
        self.init(baseURL: url, loginProcess: loginProcess, requestSerializer:AFJSONRequestSerializer(), responseSerializer: JSONResponseSerializer())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func send(_ request: ServiceRequest) -> URLSessionDataTask? {
        return internalSend(request, progress: nil, completion: nil) as? URLSessionDataTask
    }
        
    public func sendWith<T: ServiceRequest>(_ request: T, completion: @escaping (T, Error?)->()) -> URLSessionDataTask? {
        return internalSend(request, progress: nil, completion: completion) as? URLSessionDataTask
    }
    
    public func upload<T: FileRequest>(_ request: T, progress: RequestProgress?, completion: ((T, Error?)->())?) -> URLSessionUploadTask? {
        return internalSend(request, progress: progress, completion: completion) as? URLSessionUploadTask
    }
    
    public func download<T: FileRequest>(_ request: T, progress: RequestProgress?, completion: ((T, Error?)->())?) -> URLSessionDownloadTask? {
        return internalSend(request, progress: progress, completion: completion) as? URLSessionDownloadTask
    }
    
    // by default it checks error for 401 code
    open func isFailedAuthorization(_ request: ServiceRequest, error: RequestError) -> Bool {
        return error.code == authFailedCode
    }
    
    open func requestWillSend(_ request: NSMutableURLRequest, serviceRequest: ServiceRequest) {
        let requestId = UUID().uuidString
        request.setValue(requestId, forHTTPHeaderField: "X-Request-id")
        if let token = authorizationToken {
            request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        }
        log(message: "sending request with id:\(requestId)")
    }
}

@available(swift, obsoleted: 1.0)
public extension ServiceProvider {
    
    @objc func send(_ request: ServiceRequest, completion: @escaping (ServiceRequest, Error?)->()) -> URLSessionDataTask? {
        return sendWith(request, completion: completion)
    }
    
    @objc func uploadFile(_ request: FileUpload, progress: RequestProgress?, completion: ((FileUpload, Error?)->())?) -> URLSessionUploadTask? {
        return upload(request, progress: progress, completion: completion)
    }
    
    @objc func downloadFile(_ request: FileRequest, progress: RequestProgress?, completion: ((FileRequest, Error?)->())?) -> URLSessionDownloadTask? {
        return download(request, progress: progress, completion: completion)
    }
}

fileprivate extension ServiceProvider {
    
    func log(message: String) {
        if enabledLogging {
            if #available(iOS 10.0, *) {
                os_log("%@", message)
            } else {
                print(message)
            }
        }
    }
    
    func internalSend<T: ServiceRequest>(_ originalRequest: T, progress: RequestProgress?, completion: ((T, Error?)->())?) -> URLSessionTask? {
        return combiner.run(type(of: originalRequest),
                            key: originalRequest.reusing()?.reuseId(),
                            completion: completion,
                            progress: progress) { (completion, progress) -> AnyObject? in
                                
                                return enque(originalRequest, progress:progress, completion: { (innerRequest, error) in
                                    
                                    if let error = error as? RequestError, error.code == self.authFailedCode {
                                        print("request failed auth " + innerRequest.path())
                                    }
                                    
                                    if let error = error as? RequestError, let loginProcess = self.loginProcess, self.isFailedAuthorization(innerRequest, error: error) && originalRequest.canAskLogin() {
                                        
                                        print("request failed auth but inserted to queue" + innerRequest.path())
                                        
                                        _ = self.combiner.run(ServiceRequest.self,
                                                              key: "ServiceProviderInnerRelogin",
                                                              completion: { (request, error) in
                                                                
                                                                if error == nil {
                                                                    print("retry request " + innerRequest.path())
                                                                    
                                                                    _ = self.enque(innerRequest, progress: progress, completion: completion)
                                                                } else {
                                                                    completion(innerRequest, error)
                                                                }
                                                                
                                        }, progress: nil) { (completion, _) -> AnyObject? in
                                            loginProcess({ (error) in
                                                completion(innerRequest, error)
                                            })
                                            return nil
                                        }
                                        
                                    } else {
                                        completion(innerRequest, error)
                                    }
                                })
            } as? URLSessionTask
    }
    
    func requestFor(_ serviceRequest: ServiceRequest) throws -> NSMutableURLRequest {
        var error: NSError?
        
        var request: NSMutableURLRequest?
        
        if let fileRequest = serviceRequest as? FileUpload {
            request = requestSerializer.multipartFormRequest(withMethod: fileRequest.method(),
                                                             urlString: URL(string: fileRequest.path(), relativeTo: baseURL)?.absoluteString ?? baseURL!.absoluteString,
                                                             parameters: fileRequest.requestContent() as? [String : Any],
                                                             constructingBodyWith: { (formData) in
                                                            
                                                                if let path = fileRequest.filePath(), path.count > 0 {
                                                                
                                                                    try? formData.appendPart(withFileURL: URL(fileURLWithPath: path),
                                                                                             name: fileRequest.formFileField())
                                                                
                                                                } else if let data = fileRequest.fileData, let name = fileRequest.fileName {
                                                                
                                                                    formData.appendPart(withFileData: data,
                                                                                        name: fileRequest.formFileField(),
                                                                                        fileName: name,
                                                                                        mimeType: fileRequest.mimeType())
                                                                }
                                                            }, error: &error)
            
        } else {
            request = requestSerializer.request(withMethod: serviceRequest.method(),
                                                urlString: (URL(string:serviceRequest.path(), relativeTo:baseURL!) ?? baseURL!).absoluteString,
                                                parameters: serviceRequest.requestContent(),
                                                error: &error)
        }
        
        if let error = error {
            throw error
        }
        if request == nil {
            throw RequestError(code: 0, description: "Cannot send request")
        }
        return request!
    }
    
    func enque<T: ServiceRequest>(_ request: T, progress:RequestProgress?, completion: @escaping (T, Error?)->()) -> URLSessionTask? {
        
        var task: URLSessionTask?
        var urlRequest: NSMutableURLRequest
        
        do {
            urlRequest = try requestFor(request)
            urlRequest.setValue(request.acceptableContentType(), forHTTPHeaderField: "Accept")

            requestWillSend(urlRequest, serviceRequest: request)
            request.customizing()?.requestWillSend(urlRequest)
            
            if let fileRequest = request as? FileRequest {
                
                let updateProgress = { (progressObj: Progress) in
                    DispatchQueue.main.async {
                        progress?(progressObj.fractionCompleted)
                    }
                }
                
                if fileRequest as? FileUpload != nil {
                    
                    task = uploadTask(withStreamedRequest: urlRequest as URLRequest, progress: updateProgress, completionHandler: { (response, object, error) in
                        let httpResponse = response as! HTTPURLResponse
                        self.process(response: httpResponse, object: object, error: error, request: request, completion: completion)
                    })
                } else {
                    
                    if let filePath = fileRequest.filePath() {
                        
                        task = downloadTask(with: urlRequest as URLRequest, progress: updateProgress, destination: { (targetURL, _) -> URL in
                            return URL(fileURLWithPath: filePath)
                        }, completionHandler: { (response, url, error) in
                            
                            let httpResponse = response as! HTTPURLResponse
                            self.process(response: httpResponse, object: nil, error: error, request: request, completion: completion)
                        })
                        
                    } else {
                        task = dataTask(with: urlRequest as URLRequest, uploadProgress: nil, downloadProgress: updateProgress, completionHandler: { (response, object, error) in
                        
                            if error == nil, let data = object as? Data {
                                fileRequest.fileData = data
                            }
                            let httpResponse = response as! HTTPURLResponse
                            self.process(response: httpResponse, object: object, error: error, request: request, completion: completion)
                        })
                    }
                }
            } else {
                
                task = dataTask(with: urlRequest as URLRequest, uploadProgress: nil, downloadProgress: nil, completionHandler: { (response, object, error) in
                    
                    let httpResponse = response as! HTTPURLResponse
                    self.process(response: httpResponse, object: object, error: error, request: request, completion: completion)
                })
            }
            
        } catch {
            completion(request, error)
            return nil
        }
        
        log(message: "request url: \(urlRequest.url!.absoluteString)")
        if let headers = urlRequest.allHTTPHeaderFields {
            log(message: "request headers: \(headers.json()))")
        }
        
        if let body = urlRequest.httpBody, request as? FileRequest == nil {
            log(message: "request body: \(String(data:body, encoding:String.Encoding(rawValue: requestSerializer.stringEncoding)) ?? "Cannot parse body")")
        }
        
        task?.resume()
        
        return task
    }
    
    func process<T: ServiceRequest>(response: HTTPURLResponse, object: Any?, error: Error?, request: T, completion: @escaping (T, Error?)->()) {
        
        DispatchQueue.global(qos: .default).async {
        
            self.log(message: "response code: \(response.statusCode)")
            self.log(message: "response headers: \(response.allHeaderFields.json())")
            
            var resultError = error
            
            if let converting = request.errorConverting(), resultError == nil {
                resultError = converting.validate(response: object, httpResponse: response)
            }
            
            if let mime = response.mimeType, mime.hasPrefix("application") || mime.hasPrefix("text") {
                if let object = object as? [AnyHashable : Any] {
                    self.log(message: "Response body: \(object.json())")
                } else if let object = object as? [Any] {
                    self.log(message: "Response body: \(object.json())")
                } else if let object = object as? Data {
                    self.log(message: "Response body: \(String(data:object, encoding:String.Encoding(rawValue: self.requestSerializer.stringEncoding)) ?? "Cannot parse body")")
                }
            }
            
            if let error = resultError {
                self.log(message: "request error: \(error.localizedDescription)")
                
                if let converting = request.errorConverting() {
                    resultError = converting.convert(responseError: error)
                }
                
                DispatchQueue.main.async {
                    completion(request, resultError)
                }
                return
            }
            
            var validObject = object
            
            if let key = self.responserKey, let dict = object as? [AnyHashable:Any] {
                validObject = dict[key]
            }
            if let object = validObject {
                request.process(response: object)
            }
            
            DispatchQueue.main.async {
                completion(request, nil)
            }
        }
    }
}
