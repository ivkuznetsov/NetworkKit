//
//  FileRequest.swift
//  NetworkKit
//
//  Created by Ilya Kuznetsov on 11/21/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation

@objc public protocol FileRequest: ServiceRequest {
    
    //destination for download, source for upload
    func filePath() -> String?
    
    //if filePath returns nil, all data should be here
    var fileData: Data? { get set }
    var fileName: String? { get set }
}

@objc public protocol FileUpload: FileRequest {
    
    func mimeType() -> String
    
    func formFileField() -> String
}
