//
//  FTPPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import Foundation
import Citadel
import NIO

/// SFTPPublisher handles the upload of a static site using SFTP
class FTPPublisher: Publisher {
    private let host: String
    private let port: Int
    private let username: String
    private let password: String
    private let remotePath: String
    
    var publisherType: PublisherType { .ftp }
    
    init(
        host: String,
        port: Int,
        username: String,
        password: String,
        remotePath: String,
        useSFTP: Bool
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.remotePath = remotePath
        
        if !useSFTP {
            print("⚠️ Warning: Only SFTP is supported. FTP mode will be ignored.")
        }
    }
    
    /// Publishes the static site from the given directory
    func publish(directoryURL: URL, statusUpdate: @escaping (String) -> Void = { _ in }) async throws -> URL? {
        statusUpdate("Starting SFTP file upload to \(host):\(port)...")
        
        try await uploadDirectory(directoryURL, statusUpdate: statusUpdate)
        
        statusUpdate("SFTP upload completed")
        return nil // SFTP publisher doesn't return a local URL, as content is published remotely
    }
    
    /// Uploads the contents of a directory to the SFTP server
    /// - Parameters:
    ///   - directory: The local directory containing the site files
    ///   - statusUpdate: Closure for updating status messages
    private func uploadDirectory(_ directory: URL, statusUpdate: @escaping (String) -> Void) async throws {
        // Use file enumeration to upload all files
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw FTPPublisherError.directoryEnumerationFailed
        }
        
        // First, count total files to upload for progress reporting
        var filesToUpload: [URL] = []
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if attributes.isRegularFile == true {
                filesToUpload.append(fileURL)
            }
        }
        
        let totalFiles = filesToUpload.count
        statusUpdate("Found \(totalFiles) files to upload")
        
        var fileCount = 0
        var uploadErrors: [String] = []
        
        // Connect to the server
        let client: SSHClient
        do {
            statusUpdate("Creating SFTP connection to \(host):\(port)...")
            client = try await SSHClient.connect(host: host,
                                                 port: port,
                                                 authenticationMethod: .passwordBased(
                                                     username: username,
                                                     password: password
                                                 ),
                                                 hostKeyValidator: .acceptAnything(), // Note: In production, consider using a stricter validator)
                                                 reconnect: .never)
            statusUpdate("Connected and authenticated to \(host)")
        } catch {
            print("❌ SFTP connection failed: \(error.localizedDescription)")
            statusUpdate("Connection failed: \(error.localizedDescription)")
            throw FTPPublisherError.connectionFailed("Failed to connect to \(host):\(port) - \(error.localizedDescription)")
        }
        
        // Create SFTP session
        statusUpdate("Opening SFTP session...")
        let sftp = try await client.openSFTP()
        
        // Track processed directories to avoid redundant checks/creation
        var processedDirectories: Set<String> = []
        
        // Upload each file to SFTP
        for (index, fileURL) in filesToUpload.enumerated() {
            // Determine the relative path from the base directory
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path,
                with: ""
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Combine with remote path
            let remoteFilePath = remotePath.hasSuffix("/") ?
                "\(remotePath)\(relativePath)" :
                "\(remotePath)/\(relativePath)"
            
            // Get the remote directory path for this file
            let remoteFileComponents = remoteFilePath.components(separatedBy: "/")
            let remoteDirectoryPath = remoteFileComponents.dropLast().joined(separator: "/")
            
            // Create remote directory if it doesn't exist yet and isn't in our processed list
            if !processedDirectories.contains(remoteDirectoryPath) {
                statusUpdate("Creating remote directory: \(remoteDirectoryPath)")
                try await createRemoteDirectoryStructure(sftp: sftp, path: remoteDirectoryPath)
                processedDirectories.insert(remoteDirectoryPath)
            }
            
            // Update status with current file being uploaded
            let progressPercent = Int(Double(index + 1) / Double(totalFiles) * 100)
            statusUpdate("Uploading file \(index + 1)/\(totalFiles) (\(progressPercent)%): \(relativePath)")
            
            do {
                // Read file data
                let fileData = try Data(contentsOf: fileURL)
                
                // Upload the file
                try await uploadFile(
                    sftp: sftp,
                    fileData: fileData,
                    remotePath: remoteFilePath
                )
                
                fileCount += 1
                
            } catch {
                print("❌ Error uploading \(relativePath): \(error.localizedDescription)")
                statusUpdate("Error uploading \(relativePath): \(error.localizedDescription)")
                uploadErrors.append(
                    "\(relativePath): \(error.localizedDescription)"
                )
            }
        }
        
        // Close the SFTP session and SSH connection
        statusUpdate("Closing SFTP connection...")
        try await sftp.close()
        try await client.close()
        
        statusUpdate("Completed upload of \(fileCount) files to \(host)")
        
        if fileCount == 0 {
            throw FTPPublisherError.ftpUploadFailed("No files were uploaded")
        }
        
        if !uploadErrors.isEmpty {
            throw FTPPublisherError.ftpUploadFailed(
                "Failed to upload some files: \(uploadErrors.joined(separator: ", "))"
            )
        }
    }
    
    /// Upload a file to the SFTP server
    private func uploadFile(sftp: SFTPClient, fileData: Data, remotePath: String) async throws {
        // Convert Data to ByteBuffer for NIO
        var buffer = ByteBuffer(bytes: [UInt8](fileData))
        
        try await sftp.withFile(
            filePath: remotePath,
            flags: [.write, .create, .truncate]
        ) { file in
            try await file.write(buffer)
        }
    }
    
    /// Create remote directory structure recursively
    private func createRemoteDirectoryStructure(sftp: SFTPClient, path: String) async throws {
        // Split the path into components
        let pathComponents = path.split(separator: "/").map(String.init)
        var currentPath = ""
        
        // Build the path incrementally and create each directory level
        for component in pathComponents {
            if currentPath.isEmpty {
                currentPath = component
            } else {
                currentPath += "/\(component)"
            }
            
            do {
                // Try to create the directory - might fail if it already exists
                try await sftp.createDirectory(atPath: currentPath)
            } catch {
                // Check if the directory exists to distinguish between "already exists" vs. real errors
                do {
                    // Try to list the directory to see if it exists
                    _ = try await sftp.listDirectory(atPath: currentPath)
                    // If we get here, the directory exists, so we can continue
                } catch {
                    // If listing fails too, then the directory doesn't exist and creation genuinely failed
                    throw FTPPublisherError.ftpUploadFailed("Failed to create directory \(currentPath): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Error types that can occur during SFTP operations
    enum FTPPublisherError: Error, LocalizedError {
        case directoryEnumerationFailed
        case ftpUploadFailed(String)
        case connectionFailed(String)
        case authenticationFailed(String)
        
        var localizedDescription: String {
            switch self {
            case .directoryEnumerationFailed:
                return "Failed to enumerate directory contents"
            case .ftpUploadFailed(let message):
                return "SFTP upload failed: \(message)"
            case .connectionFailed(let message):
                return "SFTP connection failed: \(message)"
            case .authenticationFailed(let message):
                return "SFTP authentication failed: \(message)"
            }
        }
    }
}
