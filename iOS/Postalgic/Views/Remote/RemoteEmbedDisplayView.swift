//
//  RemoteEmbedDisplayView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI
import WebKit

// MARK: - Authenticated Image Loader

/// Loads an image from a URL with Basic Auth headers
struct AuthenticatedImage: View {
    let url: URL
    let authHeader: String

    @State private var uiImage: UIImage?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else if isLoading {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(ProgressView())
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        var request = URLRequest(url: url)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                failed = true
                isLoading = false
                return
            }
            uiImage = image
            isLoading = false
        } catch {
            failed = true
            isLoading = false
        }
    }
}

// MARK: - Main Display View

struct RemoteEmbedDisplayView: View {
    let embed: RemoteEmbed
    let serverBaseURL: String
    let blogId: String
    let authHeader: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch embed.type {
            case "youtube":
                RemoteYouTubeEmbedView(embed: embed)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            case "link":
                RemoteLinkEmbedView(embed: embed, serverBaseURL: serverBaseURL, blogId: blogId, authHeader: authHeader)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            case "image":
                RemoteImageEmbedDisplayView(embed: embed, serverBaseURL: serverBaseURL, blogId: blogId, authHeader: authHeader)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - YouTube

private struct RemoteYouTubeEmbedView: View {
    let embed: RemoteEmbed

    var body: some View {
        if let videoId = embed.videoId ?? extractVideoId() {
            WebViewContainer(urlString: "https://www.youtube.com/embed/\(videoId)")
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Invalid YouTube URL")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
        }
    }

    private func extractVideoId() -> String? {
        guard let url = embed.url else { return nil }
        return Utils.extractYouTubeId(from: url)
    }
}

// MARK: - Link

private struct RemoteLinkEmbedView: View {
    let embed: RemoteEmbed
    let serverBaseURL: String
    let blogId: String
    let authHeader: String

    var body: some View {
        if let urlString = embed.url, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 12) {
                    if let imgURL = linkImageURL {
                        if isServerURL(imgURL) {
                            AuthenticatedImage(url: imgURL, authHeader: authHeader)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                        } else {
                            AsyncImage(url: imgURL) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    linkPlaceholder
                                @unknown default:
                                    Rectangle().foregroundColor(.gray.opacity(0.3))
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                        }
                    } else {
                        linkPlaceholder
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let title = embed.title {
                            Text(title)
                                .font(.headline)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }

                        if let description = embed.description {
                            Text(description)
                                .font(.subheadline)
                                .lineLimit(3)
                                .foregroundColor(.secondary)
                        }

                        Text(urlString)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemBackground))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var linkImageURL: URL? {
        if let imageFilename = embed.imageFilename {
            return URL(string: "\(serverBaseURL)/uploads/\(blogId)/\(imageFilename)")
        }
        if let imageUrl = embed.imageUrl {
            return URL(string: imageUrl)
        }
        return nil
    }

    private func isServerURL(_ url: URL) -> Bool {
        url.absoluteString.hasPrefix(serverBaseURL)
    }

    private var linkPlaceholder: some View {
        Rectangle()
            .foregroundColor(.gray.opacity(0.3))
            .overlay(
                Image(systemName: "link")
                    .foregroundColor(.gray)
            )
            .frame(width: 80, height: 80)
    }
}

// MARK: - Image Gallery

private struct RemoteImageEmbedDisplayView: View {
    let embed: RemoteEmbed
    let serverBaseURL: String
    let blogId: String
    let authHeader: String
    @State private var currentImageIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            let sortedImages = (embed.images ?? []).sorted { ($0.order ?? 0) < ($1.order ?? 0) }

            if sortedImages.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No images available")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
            } else {
                ZStack(alignment: .bottom) {
                    if let imgURL = imageURL(for: sortedImages[safe: currentImageIndex]) {
                        AuthenticatedImage(url: imgURL, authHeader: authHeader)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 100, maxHeight: 400)
                    }

                    if sortedImages.count > 1 {
                        Text("\(currentImageIndex + 1) / \(sortedImages.count)")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(8)

                        HStack {
                            Button {
                                withAnimation {
                                    currentImageIndex = (currentImageIndex - 1 + sortedImages.count) % sortedImages.count
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            Button {
                                withAnimation {
                                    currentImageIndex = (currentImageIndex + 1) % sortedImages.count
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }

                if sortedImages.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<sortedImages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentImageIndex ? Color.accentColor : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation {
                                        currentImageIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
    }

    private func imageURL(for image: RemoteEmbedImage?) -> URL? {
        guard let image = image else { return nil }
        return URL(string: "\(serverBaseURL)/uploads/\(blogId)/\(image.filename)")
    }
}
