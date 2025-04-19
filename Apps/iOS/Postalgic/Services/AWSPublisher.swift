//
//  AWSPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation

/// AWSPublisher handles the upload of a static site to an S3 bucket
/// and creates a CloudFront invalidation.
///
/// This implementation uses a modular approach that separates the AWS
/// credentials handling from the core functionality, making it easier
/// to implement with different AWS SDK versions.
class AWSPublisher {
    private let region: String
    private let bucket: String
    private let distributionId: String
    private let identityPoolId: String
    
    init(region: String, bucket: String, distributionId: String, identityPoolId: String) {
        self.region = region
        self.bucket = bucket
        self.distributionId = distributionId
        self.identityPoolId = identityPoolId
    }
    
    /// Uploads the contents of a directory to an S3 bucket
    /// - Parameter directory: The local directory containing the site files
    func uploadDirectory(_ directory: URL) async throws {
        // In a real implementation, this would:
        // 1. Initialize the AWS SDK
        // 2. Set up Cognito credentials provider using the identity pool
        // 3. Create an S3 client with the credentials
        // 4. Upload all files to the bucket
        
        // For now we'll log what would happen
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        guard let enumerator = enumerator else {
            throw AWSPublisherError.directoryEnumerationFailed
        }
        
        print("💭 AWSPublisher would upload files to S3:")
        print("💭 Region: \(region)")
        print("💭 Bucket: \(bucket)")
        print("💭 Using Cognito Identity Pool: \(identityPoolId)")
        
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard attributes.isRegularFile == true else { continue }
            
            // Determine the relative path from the base directory
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            print("💭 Would upload: \(relativePath)")
            fileCount += 1
        }
        
        print("💭 Would upload \(fileCount) files total")
        
        // NOTE: To implement this function with the AWS SDK:
        // 1. Add AWS SDK dependencies to your project
        // 2. Configure AWS Cognito for your app
        // 3. Replace this implementation with calls to the AWS SDK
    }
    
    /// Creates a CloudFront cache invalidation for the distribution
    func invalidateCache() async throws {
        // In a real implementation, this would:
        // 1. Initialize the AWS SDK
        // 2. Set up Cognito credentials provider using the identity pool
        // 3. Create a CloudFront client with the credentials
        // 4. Create an invalidation for the specified paths
        
        print("💭 AWSPublisher would create CloudFront invalidation:")
        print("💭 Region: \(region)")
        print("💭 Distribution ID: \(distributionId)")
        print("💭 Paths to invalidate: /*")
        print("💭 Using Cognito Identity Pool: \(identityPoolId)")
        
        // NOTE: To implement this function with the AWS SDK:
        // 1. Add AWS SDK dependencies to your project
        // 2. Configure AWS Cognito for your app
        // 3. Replace this implementation with calls to the AWS SDK
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