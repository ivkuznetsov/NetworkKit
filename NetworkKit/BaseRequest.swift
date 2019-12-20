//
//  BaseRequest.swift
//  NetworkKit
//
//  Created by Ilya Kuznetsov on 12/7/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation

open class BaseRequest: NSObject, ServiceRequest {
    
    open func acceptableContentType() -> String {
        return "application/json"
    }
    
    open func method() -> String {
        return "POST"
    }
    
    open func path() -> String {
        return "(request_path_here)"
    }
    
    open func requestDictionary() -> [String : Any]? {
        return nil
    }
    
    open func process(response: Any) {
        
    }
    
    open func canAskLogin() -> Bool {
        return true
    }
}

extension BaseRequest: RequestCustomizing {
    
    open func requestWillSend(_ request: NSMutableURLRequest) {
        
    }
}

extension BaseRequest: RequestReusing {
    
    open func reuseId() -> String? {
        return nil
    }
}

extension BaseRequest: RequestErrorConverting {
    
    open func convert(responseError: Error) -> Error? {
        return responseError
    }
    
    open func validate(response: Any?, httpResponse: HTTPURLResponse) -> Error? {
        
        let acceptableCodes = IndexSet(integersIn: 200..<301)
        
        if !acceptableCodes.contains(httpResponse.statusCode) {
            return RequestError(code: httpResponse.statusCode, description: "Some server error occured")
        }
        return nil
    }
}
