//
//  JSONResponseSerializer.swift
//  NetworkKit
//
//  Created by Ilya Kuznetsov on 11/21/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import AFNetworking

open class JSONResponseSerializer: AFJSONResponseSerializer {
    
    public override init() {
        super.init()
        self.acceptableStatusCodes = IndexSet(integersIn: 200..<551)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func responseObject(for response: URLResponse?, data: Data?, error: NSErrorPointer) -> Any? {
        let object = super.responseObject(for: response, data: data, error: error)
        
        if let pointer = error, let err = pointer.pointee, err.domain == AFURLResponseSerializationErrorDomain && err.code == NSURLErrorCannotDecodeContentData {
            pointer.pointee = nil
            
            return data
        }
        
        if let response = response as? HTTPURLResponse, response.statusCode == 200, let data = data, let pointer = error, let err = pointer.pointee, err.domain == NSCocoaErrorDomain, err.code == 3840 {
            if let string = String(data: data, encoding: .utf8) {
                if string.count >= 2, string.hasPrefix("\""), string.hasSuffix("\"") {
                    pointer.pointee = nil
                    return string
                } else if let number = Double(string) {
                    pointer.pointee = nil
                    return number
                } else if string == "null" {
                    pointer.pointee = nil
                    return NSNull()
                }
            }
        }
        
        return object
    }
    
}
