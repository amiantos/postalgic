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
            Log.warn("Only SFTP is supported. FTP mode will be ignored.")
        }
    }
    
    /// Publishes the static site from the given directory
    func publish(directoryURL: URL, statusUpdate: @escaping (String) -> Void = { _ in }) async throws -> URL? {
        statusUpdate("Starting SFTP file upload to \(host):\(port)...")
        
        try await uploadDirectory(directoryURL, statusUpdate: statusUpdate)
        
        statusUpdate("SFTP upload completed")
        return nil // SFTP publisher doesn't return a local URL, as content is published remotely
    }
    
    /// Publishes only modified files and removes deleted files
    func smartPublish(directoryURL: URL, modifiedFiles: [String], deletedFiles: [String], statusUpdate: @escaping (String) -> Void) async throws -> URL? {
        let fileManager = FileManager.default
        statusUpdate("Starting smart SFTP upload to \(host):\(port)...")
        
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
                                               hostKeyValidator: .acceptAnything(),
                                               reconnect: .never)
            statusUpdate("Connected and authenticated to \(host)")
        } catch {
            Log.error("SFTP connection failed: \(error.localizedDescription)")
            statusUpdate("Connection failed: \(error.localizedDescription)")
            throw FTPPublisherError.connectionFailed("Failed to connect to \(host):\(port) - \(error.localizedDescription)")
        }

        // Create SFTP session
        statusUpdate("Opening SFTP session...")
        let sftp = try await client.openSFTP()

        // Track processed directories to avoid redundant checks/creation
        var processedDirectories: Set<String> = []

        // First upload modified files
        if !modifiedFiles.isEmpty {
            statusUpdate("Preparing to upload \(modifiedFiles.count) modified files...")

            for (index, relativePath) in modifiedFiles.enumerated() {
                // Create the full file URL
                let fileURL = directoryURL.appendingPathComponent(relativePath)

                // Skip if file doesn't exist
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    continue
                }

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
                let progressPercent = Int(Double(index + 1) / Double(modifiedFiles.count) * 100)
                statusUpdate("Uploading file \(index + 1)/\(modifiedFiles.count) (\(progressPercent)%): \(relativePath)")

                do {
                    // Read file data
                    let fileData = try Data(contentsOf: fileURL)

                    // Upload the file
                    try await uploadFile(
                        sftp: sftp,
                        fileData: fileData,
                        remotePath: remoteFilePath
                    )
                } catch {
                    Log.error("Error uploading \(relativePath): \(error.localizedDescription)")
                    statusUpdate("Error uploading \(relativePath): \(error.localizedDescription)")
                    
                    // Close connections and throw the error
                    try? await sftp.close()
                    try? await client.close()
                    throw FTPPublisherError.ftpUploadFailed("Failed to upload \(relativePath): \(error.localizedDescription)")
                }
            }
        }
        
        // Then delete removed files
        if !deletedFiles.isEmpty {
            statusUpdate("Deleting \(deletedFiles.count) removed files...")
            
            for (index, relativePath) in deletedFiles.enumerated() {
                // Combine with remote path
                let remoteFilePath = remotePath.hasSuffix("/") ?
                    "\(remotePath)\(relativePath)" :
                    "\(remotePath)/\(relativePath)"
                
                // Update status
                statusUpdate("Deleting file \(index + 1)/\(deletedFiles.count): \(relativePath)")
                
                do {
                    // Try to delete the file
                    try await sftp.remove(at: remoteFilePath)
                } catch {
                    // Just log the error but continue with other files
                    Log.warn("Error deleting \(relativePath): \(error.localizedDescription)")
                    statusUpdate("Warning: Could not delete \(relativePath): \(error.localizedDescription)")
                }
            }
        }

        // Close the SFTP session and SSH connection
        statusUpdate("Closing SFTP connection...")
        try await sftp.close()
        try await client.close()
        
        statusUpdate("Smart SFTP upload completed")
        return nil
    }
    
    /// Uploads the contents of a directory to the SFTP server
    /// - Parameters:
    ///   - directory: The local directory containing the site files
    ///   - statusUpdate: Closure for updating status messages
    private func uploadDirectory(_ directory: URL, statusUpdate: @escaping (String) -> Void) async throws {
        // Use file enumeration to collect files before async operations
        let fileManager = FileManager.default
        
        // Collect all files before entering async context
        func collectFiles() throws -> [URL] {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw FTPPublisherError.directoryEnumerationFailed
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
            Log.error("SFTP connection failed: \(error.localizedDescription)")
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
                Log.error("Error uploading \(relativePath): \(error.localizedDescription)")
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
        let buffer = ByteBuffer(bytes: [UInt8](fileData))
        
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
    
    // MARK: - Remote Hash File Support

    /// Path for the remote hash file (relative to remotePath)
    private static let hashFileName = ".postalgic/hashes.json"

    /// Fetches the remote hash file from SFTP for cross-client change detection
    func fetchRemoteHashes() async -> RemoteHashFile? {
        do {
            // Connect to the server
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )

            defer {
                Task { try? await client.close() }
            }

            let sftp = try await client.openSFTP()
            defer {
                Task { try? await sftp.close() }
            }

            // Build the full path
            let hashFilePath = remotePath.hasSuffix("/") ?
                "\(remotePath)\(Self.hashFileName)" :
                "\(remotePath)/\(Self.hashFileName)"

            // Try to read the file
            let data = try await sftp.withFile(filePath: hashFilePath, flags: .read) { file in
                try await file.readAll()
            }

            // Convert ByteBuffer to Data
            let fileData = Data(buffer: data)

            let hashFile = try JSONDecoder().decode(RemoteHashFile.self, from: fileData)
            Log.debug("Found remote hash file from \(hashFile.publishedBy) with \(hashFile.fileHashes.count) files")
            return hashFile

        } catch {
            Log.debug("No remote hash file found (or error): \(error.localizedDescription)")
            return nil
        }
    }

    /// Uploads the hash file to SFTP after successful publish
    func uploadHashFile(hashes: [String: String]) async throws {
        let hashFile = RemoteHashFile(publishedBy: "ios", fileHashes: hashes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(hashFile)

        // Connect to the server
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: .passwordBased(username: username, password: password),
            hostKeyValidator: .acceptAnything(),
            reconnect: .never
        )

        defer {
            Task { try? await client.close() }
        }

        let sftp = try await client.openSFTP()
        defer {
            Task { try? await sftp.close() }
        }

        // Build the full path
        let hashFilePath = remotePath.hasSuffix("/") ?
            "\(remotePath)\(Self.hashFileName)" :
            "\(remotePath)/\(Self.hashFileName)"

        // Ensure .postalgic directory exists
        let hashDirPath = remotePath.hasSuffix("/") ?
            "\(remotePath).postalgic" :
            "\(remotePath)/.postalgic"

        try await createRemoteDirectoryStructure(sftp: sftp, path: hashDirPath)

        // Upload the file
        try await uploadFile(sftp: sftp, fileData: data, remotePath: hashFilePath)
        Log.debug("Uploaded remote hash file with \(hashes.count) file hashes")
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
