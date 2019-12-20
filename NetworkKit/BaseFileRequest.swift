//
//  BaseFileRequest.swift
//  NetworkKit
//
//  Created by Ilya Kuznetsov on 12/7/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation

open class BaseFileRequest: BaseRequest, FileRequest {
    
    open var fileData: Data?
    open var fileName: String?
    
    open func filePath() -> String? {
        return nil
    }
}

open class BaseFileUploadRequest: BaseFileRequest, FileUpload {
    
    open func mimeType() -> String {
        return "application/octet-stream"
    }
    
    open func formFileField() -> String {
        return "data[file]"
    }
}
