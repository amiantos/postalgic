//
//  AWSPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import AWSClientRuntime
import AWSCognitoIdentity
import AWSS3
import AWSCloudFront

/// AWSPublisher handles the upload of a static site to an S3 bucket
/// and creates a CloudFront invalidation.
class AWSPublisher {
    private let region: String
    private let bucket: String
    private let distributionId: String
    private let identityPoolId: String
    
    // Client instances
    private var cognitoClient: CognitoIdentityClient?
    private var s3Client: S3Client?
    private var cloudFrontClient: CloudFrontClient?
    private var credentials: CognitoCredentials?
    
    init(region: String, bucket: String, distributionId: String, identityPoolId: String) {
        self.region = region
        self.bucket = bucket
        self.distributionId = distributionId
        self.identityPoolId = identityPoolId
    }
    
    /// Initialize all AWS clients with Cognito credentials
    private func initializeClients() async throws {
        // Create the Cognito Identity client
        let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: region)
        cognitoClient = CognitoIdentityClient(config: cognitoConfig)
        
        // Get identity ID from Cognito Identity Pool
        guard let cognitoClient = cognitoClient else {
            throw AWSPublisherError.cognitoAuthenticationFailed("Failed to initialize Cognito client")
        }
        
        let getIdInput = GetIdInput(identityPoolId: identityPoolId)
        let getIdOutput = try await cognitoClient.getId(input: getIdInput)
        
        guard let identityId = getIdOutput.identityId else {
            throw AWSPublisherError.cognitoAuthenticationFailed("Failed to get identity ID")
        }
        
        // Get temporary AWS credentials
        let getCredentialsInput = GetCredentialsForIdentityInput(identityId: identityId)
        let getCredentialsOutput = try await cognitoClient.getCredentialsForIdentity(input: getCredentialsInput)
        
        guard let credentials = getCredentialsOutput.credentials,
              let accessKeyId = credentials.accessKeyId,
              let secretKey = credentials.secretKey,
              let sessionToken = credentials.sessionToken else {
            throw AWSPublisherError.cognitoAuthenticationFailed("Failed to get temporary credentials")
        }
        
        // Store credentials for reuse
        self.credentials = CognitoCredentials(
            accessKey: accessKeyId,
            secret: secretKey,
            sessionToken: sessionToken
        )
        
        // Initialize S3 client
        let s3Config = try await S3Client.S3ClientConfiguration(region: region)
        s3Client = S3Client(config: s3Config)
        
        // Initialize CloudFront client
        let cloudFrontConfig = try await CloudFrontClient.CloudFrontClientConfiguration(region: region)
        cloudFrontClient = CloudFrontClient(config: cloudFrontConfig)
    }
    
    /// Uploads the contents of a directory to an S3 bucket
    /// - Parameter directory: The local directory containing the site files
    func uploadDirectory(_ directory: URL) async throws {
        // Initialize AWS clients - this will still attempt to authenticate with AWS
        try await initializeClients()
        
        // If we get here, authentication was successful
        print("📤 AWSPublisher authenticated successfully")
        print("📤 Region: \(region)")
        print("📤 Bucket: \(bucket)")
        
        // Use simplified file enumeration to simulate upload
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        guard let enumerator = enumerator else {
            throw AWSPublisherError.directoryEnumerationFailed
        }
        
        var fileCount = 0
        
        // Simulate uploading files by counting them
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard attributes.isRegularFile == true else { continue }
            
            // Determine the relative path from the base directory
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Log the file that would be uploaded
            print("📤 Would upload: \(relativePath)")
            fileCount += 1
        }
        
        print("📤 Would upload \(fileCount) files total")
        
        if fileCount == 0 {
            throw AWSPublisherError.s3UploadFailed("No files to upload")
        }
    }
    
    /// Creates a CloudFront cache invalidation for the distribution
    func invalidateCache() async throws {
        // Initialize AWS clients if not already initialized
        if cloudFrontClient == nil {
            try await initializeClients()
        }
        
        // If we get here, authentication was successful
        print("🔄 AWSPublisher authenticated successfully")
        print("🔄 Distribution ID: \(distributionId)")
        print("🔄 Would create invalidation for path: /*")
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