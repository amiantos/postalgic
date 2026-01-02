//
//  BlogExportService.swift
//  Postalgic
//
//  Created by Claude on 12/9/25.
//

import Foundation
import SwiftData
import ZIPFoundation

/// Service for exporting blog data to a portable ZIP format
class BlogExportService {

    enum ExportError: Error, LocalizedError {
        case failedToCreateDirectory
        case failedToWriteFile(String)
        case failedToCreateZip
        case noDataToExport

        var errorDescription: String? {
            switch self {
            case .failedToCreateDirectory:
                return "Failed to create export directory"
            case .failedToWriteFile(let filename):
                return "Failed to write file: \(filename)"
            case .failedToCreateZip:
                return "Failed to create ZIP file"
            case .noDataToExport:
                return "No data to export"
            }
        }
    }

    // MARK: - Export Models

    struct ExportManifest: Codable {
        let version: String
        let exportDate: String
        let appVersion: String
        let includesCredentials: Bool
        let blogName: String
    }

    struct ExportBlog: Codable {
        let name: String
        let url: String
        let tagline: String?
        let authorName: String?
        let authorUrl: String?
        let authorEmail: String?
        let accentColor: String?
        let backgroundColor: String?
        let textColor: String?
        let lightShade: String?
        let mediumShade: String?
        let darkShade: String?
        let themeIdentifier: String?
        let createdAt: String

        // Publishing config (only if credentials included)
        let publisherType: String?
        let awsRegion: String?
        let awsS3Bucket: String?
        let awsCloudFrontDistId: String?
        let awsAccessKeyId: String?
        let awsSecretAccessKey: String?
        let ftpHost: String?
        let ftpPort: Int?
        let ftpUsername: String?
        let ftpPath: String?
        let ftpUseSFTP: Bool?
        let ftpPassword: String?
        let gitRepositoryUrl: String?
        let gitUsername: String?
        let gitBranch: String?
        let gitCommitMessage: String?
        let gitPassword: String?
    }

    struct ExportEmbed: Codable {
        let url: String
        let type: String
        let position: String
        let title: String?
        let description: String?
        let imageUrl: String?
        let imageFilename: String?
        let embedImages: [ExportEmbedImage]
        let createdAt: String
    }

    struct ExportEmbedImage: Codable {
        let filename: String
        let order: Int
        let createdAt: String
    }

    struct ExportPost: Codable {
        let id: String
        let title: String?
        let content: String
        let stub: String?
        let isDraft: Bool
        let createdAt: String
        let categoryId: String?
        let tagIds: [String]
        let embed: ExportEmbed?
    }

    struct ExportCategory: Codable {
        let id: String
        let name: String
        let description: String?
        let stub: String?
        let createdAt: String
    }

    struct ExportTag: Codable {
        let id: String
        let name: String
        let stub: String?
        let createdAt: String
    }

    struct ExportLinkItem: Codable {
        let title: String
        let url: String
        let order: Int
        let createdAt: String
    }

    struct ExportSidebarObject: Codable {
        let id: String
        let title: String
        let type: String
        let order: Int
        let content: String?
        let links: [ExportLinkItem]
        let createdAt: String
    }

    struct ExportStaticFile: Codable {
        let id: String
        let filename: String
        let mimeType: String
        let isSpecialFile: Bool
        let specialFileType: String?
        let createdAt: String
    }

    struct ExportTheme: Codable {
        let name: String
        let identifier: String
        let isCustomized: Bool
        let templates: [String: String]
        let createdAt: String
    }

    // MARK: - Date Formatter

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Export Method

    /// Exports a blog to a ZIP file
    /// - Parameters:
    ///   - blog: The blog to export
    ///   - includeCredentials: Whether to include publishing credentials
    ///   - modelContext: The SwiftData model context for fetching themes
    ///   - statusUpdate: Closure for status updates
    /// - Returns: URL to the created ZIP file
    static func exportBlog(
        _ blog: Blog,
        includeCredentials: Bool,
        modelContext: ModelContext,
        statusUpdate: @escaping (String) -> Void
    ) async throws -> URL {
        let fileManager = FileManager.default

        // Create export directory
        statusUpdate("Creating export directory...")
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitizedName = blog.name.replacingOccurrences(of: " ", with: "-").lowercased()
        let exportDirName = "postalgic-export-\(sanitizedName)-\(timestamp)"
        let exportDir = fileManager.temporaryDirectory.appendingPathComponent(exportDirName)

        // Clean up any existing directory
        if fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.removeItem(at: exportDir)
        }

        // Create directory structure
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("posts"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("categories"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("tags"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("sidebar"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("static-files"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("uploads"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("embed-images"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDir.appendingPathComponent("themes"), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Build ID maps for categories and tags
        var categoryIdMap: [PersistentIdentifier: String] = [:]
        var tagIdMap: [PersistentIdentifier: String] = [:]

        // Export manifest
        statusUpdate("Writing manifest...")
        let manifest = ExportManifest(
            version: "1.0",
            exportDate: isoFormatter.string(from: Date()),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            includesCredentials: includeCredentials,
            blogName: blog.name
        )
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: exportDir.appendingPathComponent("manifest.json"))

        // Export blog
        statusUpdate("Exporting blog settings...")
        let exportBlog = ExportBlog(
            name: blog.name,
            url: blog.url,
            tagline: blog.tagline,
            authorName: blog.authorName,
            authorUrl: blog.authorUrl,
            authorEmail: blog.authorEmail,
            accentColor: blog.accentColor,
            backgroundColor: blog.backgroundColor,
            textColor: blog.textColor,
            lightShade: blog.lightShade,
            mediumShade: blog.mediumShade,
            darkShade: blog.darkShade,
            themeIdentifier: blog.themeIdentifier,
            createdAt: isoFormatter.string(from: blog.createdAt),
            publisherType: includeCredentials ? blog.publisherType : nil,
            awsRegion: includeCredentials ? blog.awsRegion : nil,
            awsS3Bucket: includeCredentials ? blog.awsS3Bucket : nil,
            awsCloudFrontDistId: includeCredentials ? blog.awsCloudFrontDistId : nil,
            awsAccessKeyId: includeCredentials ? blog.awsAccessKeyId : nil,
            awsSecretAccessKey: includeCredentials ? blog.getAwsSecretAccessKey() : nil,
            ftpHost: includeCredentials ? blog.ftpHost : nil,
            ftpPort: includeCredentials ? blog.ftpPort : nil,
            ftpUsername: includeCredentials ? blog.ftpUsername : nil,
            ftpPath: includeCredentials ? blog.ftpPath : nil,
            ftpUseSFTP: includeCredentials ? blog.ftpUseSFTP : nil,
            ftpPassword: includeCredentials ? blog.getFtpPassword() : nil,
            gitRepositoryUrl: includeCredentials ? blog.gitRepositoryUrl : nil,
            gitUsername: includeCredentials ? blog.gitUsername : nil,
            gitBranch: includeCredentials ? blog.gitBranch : nil,
            gitCommitMessage: includeCredentials ? blog.gitCommitMessage : nil,
            gitPassword: includeCredentials ? blog.getGitPassword() : nil
        )
        let blogData = try encoder.encode(exportBlog)
        try blogData.write(to: exportDir.appendingPathComponent("blog.json"))

        // Export categories
        statusUpdate("Exporting categories...")
        for category in blog.categories {
            let exportId = UUID().uuidString
            categoryIdMap[category.persistentModelID] = exportId

            let exportCategory = ExportCategory(
                id: exportId,
                name: category.name,
                description: category.categoryDescription,
                stub: category.stub,
                createdAt: isoFormatter.string(from: category.createdAt)
            )
            let categoryData = try encoder.encode(exportCategory)
            try categoryData.write(to: exportDir.appendingPathComponent("categories/\(exportId).json"))
        }

        // Export tags
        statusUpdate("Exporting tags...")
        for tag in blog.tags {
            let exportId = UUID().uuidString
            tagIdMap[tag.persistentModelID] = exportId

            let exportTag = ExportTag(
                id: exportId,
                name: tag.name,
                stub: tag.stub,
                createdAt: isoFormatter.string(from: tag.createdAt)
            )
            let tagData = try encoder.encode(exportTag)
            try tagData.write(to: exportDir.appendingPathComponent("tags/\(exportId).json"))
        }

        // Export posts
        statusUpdate("Exporting posts...")
        for post in blog.posts {
            let exportId = UUID().uuidString

            // Map category ID
            var categoryExportId: String? = nil
            if let category = post.category {
                categoryExportId = categoryIdMap[category.persistentModelID]
            }

            // Map tag IDs
            let tagExportIds = post.tags.compactMap { tagIdMap[$0.persistentModelID] }

            // Export embed if present
            var exportEmbed: ExportEmbed? = nil
            if let embed = post.embed {
                // Export embed image data if present (for link embeds only, and only if not empty)
                var imageFilename: String? = nil
                if embed.embedType == .link,
                   let imageData = embed.imageData,
                   !imageData.isEmpty,
                   let deterministicFilename = embed.deterministicImageFilename {
                    imageFilename = deterministicFilename
                    try imageData.write(to: exportDir.appendingPathComponent("embed-images/\(imageFilename!)"))
                }

                // Export embed images (for image type embeds)
                var exportEmbedImages: [ExportEmbedImage] = []
                for embedImage in embed.images {
                    // Write image data
                    try embedImage.imageData.write(to: exportDir.appendingPathComponent("embed-images/\(embedImage.filename)"))

                    exportEmbedImages.append(ExportEmbedImage(
                        filename: embedImage.filename,
                        order: embedImage.order,
                        createdAt: isoFormatter.string(from: embedImage.createdAt)
                    ))
                }

                exportEmbed = ExportEmbed(
                    url: embed.url,
                    type: embed.type,
                    position: embed.position,
                    title: embed.title,
                    description: embed.embedDescription,
                    imageUrl: embed.imageUrl,
                    imageFilename: imageFilename,
                    embedImages: exportEmbedImages.sorted { $0.order < $1.order },
                    createdAt: isoFormatter.string(from: embed.createdAt)
                )
            }

            let exportPost = ExportPost(
                id: exportId,
                title: post.title,
                content: post.content,
                stub: post.stub,
                isDraft: post.isDraft,
                createdAt: isoFormatter.string(from: post.createdAt),
                categoryId: categoryExportId,
                tagIds: tagExportIds,
                embed: exportEmbed
            )
            let postData = try encoder.encode(exportPost)
            try postData.write(to: exportDir.appendingPathComponent("posts/\(exportId).json"))
        }

        // Export sidebar objects
        statusUpdate("Exporting sidebar content...")
        for sidebarObject in blog.sidebarObjects {
            let exportId = UUID().uuidString

            let exportLinks = sidebarObject.links.sorted { $0.order < $1.order }.map { link in
                ExportLinkItem(
                    title: link.title,
                    url: link.url,
                    order: link.order,
                    createdAt: isoFormatter.string(from: link.createdAt)
                )
            }

            let exportSidebar = ExportSidebarObject(
                id: exportId,
                title: sidebarObject.title,
                type: sidebarObject.type,
                order: sidebarObject.order,
                content: sidebarObject.content,
                links: exportLinks,
                createdAt: isoFormatter.string(from: sidebarObject.createdAt)
            )
            let sidebarData = try encoder.encode(exportSidebar)
            try sidebarData.write(to: exportDir.appendingPathComponent("sidebar/\(exportId).json"))
        }

        // Export static files
        statusUpdate("Exporting static files...")
        for staticFile in blog.staticFiles {
            let exportId = UUID().uuidString

            // Write file metadata
            let exportStaticFile = ExportStaticFile(
                id: exportId,
                filename: staticFile.filename,
                mimeType: staticFile.mimeType,
                isSpecialFile: staticFile.isSpecialFile,
                specialFileType: staticFile.specialFileType,
                createdAt: isoFormatter.string(from: staticFile.createdAt)
            )
            let metadataData = try encoder.encode(exportStaticFile)
            try metadataData.write(to: exportDir.appendingPathComponent("static-files/\(exportId).json"))

            // Write actual file data
            try staticFile.data.write(to: exportDir.appendingPathComponent("uploads/\(staticFile.filename)"))
        }

        // Export custom theme if present
        if let themeIdentifier = blog.themeIdentifier,
           themeIdentifier != "default",
           let theme = ThemeService.shared.getTheme(identifier: themeIdentifier) {
            statusUpdate("Exporting custom theme...")

            let exportTheme = ExportTheme(
                name: theme.name,
                identifier: theme.identifier,
                isCustomized: theme.isCustomized,
                templates: theme.templates,
                createdAt: isoFormatter.string(from: theme.createdAt)
            )
            let themeData = try encoder.encode(exportTheme)
            try themeData.write(to: exportDir.appendingPathComponent("themes/\(theme.identifier).json"))
        }

        // Create ZIP file
        statusUpdate("Creating ZIP file...")
        let zipFileName = "\(exportDirName).zip"
        let zipFilePath = fileManager.temporaryDirectory.appendingPathComponent(zipFileName)

        // Remove existing zip if present
        if fileManager.fileExists(atPath: zipFilePath.path) {
            try fileManager.removeItem(at: zipFilePath)
        }

        try fileManager.zipItem(at: exportDir, to: zipFilePath, shouldKeepParent: false)

        // Clean up export directory
        try? fileManager.removeItem(at: exportDir)

        statusUpdate("Export complete!")
        return zipFilePath
    }
}
