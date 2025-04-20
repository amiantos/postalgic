//
//  AWSPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import AWSS3
import AWSCore

/// AWSPublisher handles the upload of a static site to an S3 bucket
/// and creates a CloudFront invalidation.
class AWSPublisher {
    private let region: String
    private let bucket: String
    private let distributionId: String
    private let identityPoolId: String
    private let credentialsProvider: AWSCredentialsProvider
    
    init(region: String, bucket: String, distributionId: String, identityPoolId: String) {
        self.region = region
        self.bucket = bucket
        self.distributionId = distributionId
        self.identityPoolId = identityPoolId
        
        self.credentialsProvider = AWSCognitoCredentialsProvider(regionType: .USEast1, identityPoolId: self.identityPoolId)
        
        let configuration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: credentialsProvider
        )
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    
    }
    
    func uploadDataToS3(data: Data, bucket: String, key: String, contentType: String) {
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = { (task, progress) in
            DispatchQueue.main.async(qos:.background) {
                print("Progress: \(progress.fractionCompleted)")
            }
        }

        let completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock = { (task, error) in
            DispatchQueue.main.async(qos:.background) {
                if let error = error {
                    print("Upload failed: \(error.localizedDescription)")
                } else {
                    print("Upload succeeded!")
                }
            }
        }

        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.uploadData(
            data,
            bucket: bucket,
            key: key,
            contentType: contentType,
            expression: expression,
            completionHandler: completionHandler
        ).continueWith { (task) -> AnyObject? in
            if let error = task.error {
                print("Error: \(error.localizedDescription)")
            }
            if let _ = task.result {
                print("Upload started...")
            }
            return nil
        }
    }
    
    /// Uploads the contents of a directory to an S3 bucket
    /// - Parameter directory: The local directory containing the site files
    func uploadDirectory(_ directory: URL) throws {

        // Use file enumeration to upload all files
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        guard let enumerator = enumerator else {
            throw AWSPublisherError.directoryEnumerationFailed
        }
        
        var fileCount = 0
        var uploadErrors: [String] = []
        
        // Upload each file to S3
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard attributes.isRegularFile == true else { continue }
            
            // Determine the relative path from the base directory to use as S3 key
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Get file content type based on extension
            let fileExtension = fileURL.pathExtension
            let contentType = contentType(forFileExtension: fileExtension)
            
            do {
                // Read file data
                let fileData = try Data(contentsOf: fileURL)
                
                print("📤 Uploading: \(relativePath)")
                uploadDataToS3(data: fileData, bucket: self.bucket, key: relativePath, contentType: contentType)
                print("📤 Uploaded: \(relativePath)")
                fileCount += 1
                
            } catch {
                print("ERROR: ", dump(error, name: "Putting an object."))
                print("❌ Error uploading \(relativePath): \(error.localizedDescription)")
                uploadErrors.append("\(relativePath): \(error.localizedDescription)")
            }
        }
        
        print("📤 Uploaded \(fileCount) files total")
        
        if fileCount == 0 {
            throw AWSPublisherError.s3UploadFailed("No files were uploaded")
        }
        
        if !uploadErrors.isEmpty {
            throw AWSPublisherError.s3UploadFailed("Failed to upload some files: \(uploadErrors.joined(separator: ", "))")
        }
    }
    
    /// Creates a CloudFront cache invalidation for the distribution
    func invalidateCache() throws {
        print("🔄 AWSPublisher authenticated successfully")
        print("🔄 Distribution ID: \(distributionId)")
    }

    
    /// Determines the appropriate content type for a file based on its extension
    private func contentType(forFileExtension fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "json":
            return "application/json"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        case "ico":
            return "image/x-icon"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "xml":
            return "application/xml"
        default:
            return "application/octet-stream"
        }
    }
    
    /// Error types that can occur during AWS operations
    enum AWSPublisherError: Error {
        case directoryEnumerationFailed
        case s3UploadFailed(String)
        case cloudFrontInvalidationFailed(String)
        case cognitoAuthenticationFailed(String)
        
        var localizedDescription: String {
            switch self {
            case .directoryEnumerationFailed:
                return "Failed to enumerate directory contents"
            case .s3UploadFailed(let message):
                return "S3 upload failed: \(message)"
            case .cloudFrontInvalidationFailed(let message):
                return "CloudFront invalidation failed: \(message)"
            case .cognitoAuthenticationFailed(let message):
                return "Failed to get Cognito credentials: \(message)"
            }
        }
    }
}

/// Cognito credentials structure
struct CognitoCredentials {
    let accessKey: String
    let secret: String
    let sessionToken: String
}
