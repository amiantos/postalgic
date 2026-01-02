//
//  LinkMetadataService.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import Foundation
import LinkPresentation
import SwiftUI

class LinkMetadataService {
    /// Fetches metadata for a given URL
    /// - Parameter url: The URL to fetch metadata for
    /// - Returns: A tuple containing the title, description, image URL, and image data (all optional)
    static func fetchMetadata(for urlString: String) async -> (title: String?, description: String?, imageUrl: String?, imageData: Data?) {
        guard let url = URL(string: urlString) else {
            return (nil, nil, nil, nil)
        }
        
        do {
            let metadataProvider = LPMetadataProvider()
            let metadata = try await metadataProvider.startFetchingMetadata(for: url)
            
            // Get title
            let title = metadata.title
            
            // Get description
            let description = extractDescription(from: metadata)
            
            // Try getting image if available
            var imageUrl: String? = nil
            var imageData: Data? = nil
            
            if let imageProvider = metadata.imageProvider {
                // Use a continuation to bridge the completion handler-based API
                let image = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                    imageProvider.loadObject(ofClass: UIImage.self) { image, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let image = image as? UIImage {
                            continuation.resume(returning: image)
                        } else {
                            continuation.resume(throwing: NSError(domain: "LinkMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
                        }
                    }
                }
                
                if let image = image {
                    // Store the image data
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        imageData = data
                        
                        // For preview in the app, save to temp directory
                        let tempDir = FileManager.default.temporaryDirectory
                        let imageName = "\(UUID().uuidString).jpg"
                        let imageFileURL = tempDir.appendingPathComponent(imageName)
                        
                        try data.write(to: imageFileURL)
                        imageUrl = imageFileURL.absoluteString
                    }
                }
            }
            
            return (title, description, imageUrl, imageData)
        } catch {
            Log.error("Error fetching metadata: \(error.localizedDescription)")
            return (nil, nil, nil, nil)
        }
    }

    /// Fetches YouTube video title using LinkPresentation
    /// - Parameter urlString: The YouTube video URL
    /// - Returns: The video title, if available
    static func fetchYouTubeTitle(for urlString: String) async -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let metadataProvider = LPMetadataProvider()
            let metadata = try await metadataProvider.startFetchingMetadata(for: url)
            return metadata.title
        } catch {
            Log.error("Error fetching YouTube title: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func extractDescription(from metadata: LPLinkMetadata) -> String? {
        // LinkPresentation doesn't directly expose a description property,
        // so we'll use the URL's host as a simple description
        if let url = metadata.url, let host = url.host {
            return host
        }
        
        return nil
    }
}