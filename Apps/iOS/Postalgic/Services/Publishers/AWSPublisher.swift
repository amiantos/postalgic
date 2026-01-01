//
//  AWSPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import AWSCore
import AWSS3
import Foundation



/// AWSPublisher handles the upload of a static site to an S3 bucket
/// and creates a CloudFront invalidation.
class AWSPublisher: Publisher {
    private let region: String
    private let bucket: String
    private let distributionId: String
    private let accessKeyId: String
    private let secretAccessKey: String
    private let credentialsProvider: AWSCredentialsProvider
    private let configuration: AWSServiceConfiguration
    
    var publisherType: PublisherType { .aws }

    init(
        region: String,
        bucket: String,
        distributionId: String,
        accessKeyId: String,
        secretAccessKey: String
    ) {
        self.region = region
        self.bucket = bucket
        self.distributionId = distributionId
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey

        self.credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: accessKeyId,
            secretKey: secretAccessKey
        )

        self.configuration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: credentialsProvider
        )
        AWSServiceManager.default().defaultServiceConfiguration = configuration

    }
    
    /// Publishes the static site from the given directory
    func publish(directoryURL: URL, statusUpdate: @escaping (String) -> Void = { _ in }) async throws -> URL? {
        statusUpdate("Starting S3 upload...")
        try await uploadDirectory(directoryURL, statusUpdate: statusUpdate)
        statusUpdate("Upload complete. Creating CloudFront invalidation...")
        try await invalidateCache(statusUpdate: statusUpdate)
        statusUpdate("Publication complete!")
        return nil // AWS publisher doesn't return a local URL, as content is published remotely
    }
    
    /// Publishes only modified files and removes deleted files
    func smartPublish(directoryURL: URL, modifiedFiles: [String], deletedFiles: [String], statusUpdate: @escaping (String) -> Void) async throws -> URL? {
        // Upload modified files
        if !modifiedFiles.isEmpty {
            statusUpdate("Starting S3 upload of \(modifiedFiles.count) changed files...")
            try await uploadSelectedFiles(from: directoryURL, filePaths: modifiedFiles, statusUpdate: statusUpdate)
        }
        
        // Delete files that were removed
        if !deletedFiles.isEmpty {
            statusUpdate("Deleting \(deletedFiles.count) removed files from S3...")
            try await deleteFiles(paths: deletedFiles, statusUpdate: statusUpdate)
        }
        
        // Always invalidate the cache to ensure the site is fresh
        statusUpdate("Upload complete. Creating CloudFront invalidation...")
        try await invalidateCache(statusUpdate: statusUpdate)
        statusUpdate("Smart publication complete!")
        return nil
    }
    
    /// Uploads specific files from the directory to S3
    private func uploadSelectedFiles(from directoryURL: URL, filePaths: [String], statusUpdate: @escaping (String) -> Void) async throws {
        let fileManager = FileManager.default
        let totalFiles = filePaths.count
        
        statusUpdate("Preparing to upload \(totalFiles) files")
        var fileCount = 0
        var uploadErrors: [String] = []
        
        for relativePath in filePaths {
            // Create the full file URL
            let fileURL = directoryURL.appendingPathComponent(relativePath)
            
            // Skip if file doesn't exist
            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }
            
            // Get file content type based on extension
            let fileExtension = fileURL.pathExtension
            let contentType = contentType(forFileExtension: fileExtension)
            
            do {
                // Read file data
                let fileData = try Data(contentsOf: fileURL)
                
                // Update status with current file being uploaded
                fileCount += 1
                let progressPercent = Int((Double(fileCount) / Double(totalFiles)) * 100)
                statusUpdate("Uploading file \(fileCount)/\(totalFiles) (\(progressPercent)%): \(relativePath)")
                
                // Upload the file and wait for completion
                try await uploadDataToS3(
                    data: fileData,
                    bucket: self.bucket,
                    key: relativePath,
                    contentType: contentType
                )
            } catch {
                print("ERROR: ", dump(error, name: "Putting an object."))
                print("❌ Error uploading \(relativePath): \(error.localizedDescription)")
                uploadErrors.append("\(relativePath): \(error.localizedDescription)")
            }
        }
        
        statusUpdate("Completed upload of \(fileCount) files")
        
        if fileCount == 0 && totalFiles > 0 {
            throw AWSPublisherError.s3UploadFailed("No files were uploaded")
        }
        
        if !uploadErrors.isEmpty {
            throw AWSPublisherError.s3UploadFailed(
                "Failed to upload some files: \(uploadErrors.joined(separator: ", "))"
            )
        }
    }
    
    /// Deletes files from S3
    private func deleteFiles(paths: [String], statusUpdate: @escaping (String) -> Void) async throws {
        let totalFiles = paths.count
        var deleteErrors: [String] = []
        
        for (index, path) in paths.enumerated() {
            statusUpdate("Deleting file \(index + 1)/\(totalFiles): \(path)")
            
            do {
                try await deleteFileFromS3(bucket: self.bucket, key: path)
            } catch {
                print("❌ Error deleting \(path): \(error.localizedDescription)")
                deleteErrors.append("\(path): \(error.localizedDescription)")
            }
        }
        
        if !deleteErrors.isEmpty {
            throw AWSPublisherError.s3UploadFailed(
                "Failed to delete some files: \(deleteErrors.joined(separator: ", "))"
            )
        }
    }
    
    /// Deletes a file from S3
    private func deleteFileFromS3(bucket: String, key: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let deleteRequest = AWSS3DeleteObjectRequest()!
            deleteRequest.bucket = bucket
            deleteRequest.key = key
            
            AWSS3.default().deleteObject(deleteRequest) { (output, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Delete failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("Delete succeeded: \(key)")
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    func uploadDataToS3(
        data: Data,
        bucket: String,
        key: String,
        contentType: String
    ) async throws {
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = { (task, progress) in
            DispatchQueue.main.async(qos: .background) {
                print("Progress: \(progress.fractionCompleted)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let completionHandler:
                AWSS3TransferUtilityUploadCompletionHandlerBlock = {
                    (task, error) in
                    DispatchQueue.main.async(qos: .background) {
                        if let error = error {
                            print("Upload failed: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        } else {
                            print("Upload succeeded for \(key)!")
                            continuation.resume(returning: ())
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
                    continuation.resume(throwing: error)
                }
                if task.result == nil {
                    // Only consider this an error if we haven't already resolved the continuation
                    print("Upload task failed to start")
                    // We don't resolve here because the completion handler should still be called
                }
                return nil
            }
        }
    }

    /// Uploads the contents of a directory to an S3 bucket
    /// - Parameters:
    ///   - directory: The local directory containing the site files
    ///   - statusUpdate: Closure for updating status messages
    func uploadDirectory(_ directory: URL, statusUpdate: @escaping (String) -> Void) async throws {
        // Use file enumeration to collect files before async operations
        let fileManager = FileManager.default
        
        // Collect all files before entering async context
        func collectFiles() throws -> [URL] {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw AWSPublisherError.directoryEnumerationFailed
            }
            
            var files: [URL] = []
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if attributes.isRegularFile == true {
                    files.append(fileURL)
                }
            }
            return files
        }
        
        // Collect files synchronously before async operations
        let filesToUpload = try collectFiles()
        
        let totalFiles = filesToUpload.count
        statusUpdate("Found \(totalFiles) files to upload")

        var fileCount = 0
        var uploadErrors: [String] = []

        // Upload each file to S3 sequentially
        for fileURL in filesToUpload {
            // Determine the relative path from the base directory to use as S3 key
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path,
                with: ""
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // Get file content type based on extension
            let fileExtension = fileURL.pathExtension
            let contentType = contentType(forFileExtension: fileExtension)

            do {
                // Read file data
                let fileData = try Data(contentsOf: fileURL)

                // Update status with current file being uploaded
                fileCount += 1
                let progressPercent = Int((Double(fileCount) / Double(totalFiles)) * 100)
                statusUpdate("Uploading file \(fileCount)/\(totalFiles) (\(progressPercent)%): \(relativePath)")
                
                // Upload the file and wait for completion
                try await uploadDataToS3(
                    data: fileData,
                    bucket: self.bucket,
                    key: relativePath,
                    contentType: contentType
                )

            } catch {
                print("ERROR: ", dump(error, name: "Putting an object."))
                print("❌ Error uploading \(relativePath): \(error.localizedDescription)")
                uploadErrors.append("\(relativePath): \(error.localizedDescription)")
            }
        }

        statusUpdate("Completed upload of \(fileCount) files")

        if fileCount == 0 {
            throw AWSPublisherError.s3UploadFailed("No files were uploaded")
        }

        if !uploadErrors.isEmpty {
            throw AWSPublisherError.s3UploadFailed(
                "Failed to upload some files: \(uploadErrors.joined(separator: ", "))"
            )
        }
    }

    /// Creates a CloudFront cache invalidation for the distribution
    /// - Parameter statusUpdate: Closure for updating status messages
    func invalidateCache(statusUpdate: @escaping (String) -> Void) async throws {
        statusUpdate("Creating CloudFront invalidation...")
        print("🔄 AWSPublisher authenticated successfully")
        print("🔄 Distribution ID: \(distributionId)")

        // Create the invalidation JSON payload
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let callerReference = "postalgic-\(timestamp)"

        // Create the request
        let cloudFrontHost = "cloudfront.amazonaws.com"
        let endpoint = URL(
            string:
                "https://\(cloudFrontHost)/2020-05-31/distribution/\(distributionId)/invalidation"
        )!
        let request = NSMutableURLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-amz-json-1.0",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = """
            <InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2020-05-31/">
                <CallerReference>"\(callerReference)"</CallerReference>
                <Paths>
                    <Items>
                        <Path>/*</Path>
                    </Items>
                    <Quantity>1</Quantity>
                </Paths>
            </InvalidationBatch>
        """.data(using: .utf8)

        // Sign the request using AWSSignatureV4Signer
        let awsEndpoint = AWSEndpoint(
            region: .USEast1,
            serviceName: "cloudfront",
            url: endpoint
        )!
        let signer = AWSSignatureV4Signer(
            credentialsProvider: self.credentialsProvider,
            endpoint: awsEndpoint
        )
        let baseInterceptor = AWSNetworkingRequestInterceptor(
            userAgent: self.configuration.userAgent
        )
        baseInterceptor?.interceptRequest(request)
        signer.interceptRequest(request)

        // Use async/await with URLSession
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
                if let error = error {
                    let awsError = AWSPublisherError.cloudFrontInvalidationFailed(error.localizedDescription)
                    continuation.resume(throwing: awsError)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    let awsError = AWSPublisherError.cloudFrontInvalidationFailed("Invalid response")
                    continuation.resume(throwing: awsError)
                    return
                }

                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    // Successfully created invalidation
                    if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                        print("🔄 CloudFront invalidation successful: \(jsonString)")
                        
                        // Try to extract the invalidation ID if needed
                        var invalidationId = "unknown"
                        if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let invalidation = jsonData["Invalidation"] as? [String: Any],
                           let id = invalidation["Id"] as? String {
                            invalidationId = id
                        }
                        
                        statusUpdate("CloudFront invalidation created (ID: \(invalidationId))")
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(returning: ())
                    }
                } else {
                    // Handle error
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("HTTP \(httpResponse.statusCode): \(errorString)")
                        let awsError = AWSPublisherError.cloudFrontInvalidationFailed(
                            "HTTP \(httpResponse.statusCode): \(errorString)"
                        )
                        continuation.resume(throwing: awsError)
                    } else {
                        print("HTTP \(httpResponse.statusCode)")
                        let awsError = AWSPublisherError.cloudFrontInvalidationFailed(
                            "HTTP \(httpResponse.statusCode)"
                        )
                        continuation.resume(throwing: awsError)
                    }
                }
            }

            task.resume()
        }
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

    // MARK: - Remote Hash File Support

    /// Path for the remote hash file
    private static let hashFilePath = ".postalgic/hashes.json"

    /// Fetches the remote hash file from S3 for cross-client change detection
    func fetchRemoteHashes() async -> RemoteHashFile? {
        return await withCheckedContinuation { continuation in
            let getRequest = AWSS3GetObjectRequest()!
            getRequest.bucket = bucket
            getRequest.key = Self.hashFilePath

            AWSS3.default().getObject(getRequest) { (output, error) in
                if let error = error {
                    print("📦 No remote hash file found (or error): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let data = output?.body as? Data else {
                    print("📦 Remote hash file has no data")
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let hashFile = try JSONDecoder().decode(RemoteHashFile.self, from: data)
                    print("📦 Found remote hash file from \(hashFile.appSource) with \(hashFile.fileHashes.count) files")
                    continuation.resume(returning: hashFile)
                } catch {
                    print("📦 Failed to decode remote hash file: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Uploads the hash file to S3 after successful publish
    func uploadHashFile(hashes: [String: String]) async throws {
        let hashFile = RemoteHashFile(appSource: "ios", fileHashes: hashes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(hashFile)

        try await uploadDataToS3(
            data: data,
            bucket: bucket,
            key: Self.hashFilePath,
            contentType: "application/json"
        )
        print("📦 Uploaded remote hash file with \(hashes.count) file hashes")
    }

    /// Error types that can occur during AWS operations
    enum AWSPublisherError: Error {
        case directoryEnumerationFailed
        case s3UploadFailed(String)
        case cloudFrontInvalidationFailed(String)
        case authenticationFailed(String)

        var localizedDescription: String {
            switch self {
            case .directoryEnumerationFailed:
                return "Failed to enumerate directory contents"
            case .s3UploadFailed(let message):
                return "S3 upload failed: \(message)"
            case .cloudFrontInvalidationFailed(let message):
                return "CloudFront invalidation failed: \(message)"
            case .authenticationFailed(let message):
                return "AWS authentication failed: \(message)"
            }
        }
    }
}
