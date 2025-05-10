//
//  EmbedView.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import SwiftUI
import WebKit

struct EmbedView: View {
    var embed: Embed
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch embed.embedType {
            case .youtube:
                YouTubeEmbedView(embed: embed)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            case .link:
                LinkEmbedView(embed: embed)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            case .image:
                ImageEmbedView(embed: embed)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

struct YouTubeEmbedView: View {
    var embed: Embed
    @State private var videoId: String?
    
    var body: some View {
        ZStack {
            if let videoId = Utils.extractYouTubeId(from: embed.url) {
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
    }
}

struct LinkEmbedView: View {
    var embed: Embed
    
    var body: some View {
        Link(destination: URL(string: embed.url) ?? URL(string: "https://example.com")!) {
            HStack(alignment: .top, spacing: 12) {
                if let imageData = embed.imageData, let uiImage = UIImage(data: imageData) {
                    // Display from image data directly
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                } else if let imageUrl = embed.imageUrl, let url = URL(string: imageUrl) {
                    // Fallback to URL if no image data
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.3))
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "link")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Rectangle().foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                } else {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "link")
                                .foregroundColor(.gray)
                        )
                        .frame(width: 80, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title = embed.title {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                    
                    if let description = embed.embedDescription {
                        Text(description)
                            .font(.subheadline)
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(embed.url)
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

struct WebViewContainer: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Only allow the initial load, block other navigation
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}

struct ImageEmbedView: View {
    var embed: Embed
    @State private var currentImageIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            if embed.images.isEmpty {
                // Empty state
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
                let sortedImages = embed.images.sorted { $0.order < $1.order }

                // Single image view or image gallery
                ZStack(alignment: .bottom) {
                    if let imageData = sortedImages[safe: currentImageIndex]?.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 100, maxHeight: 400)
                            .clipped()
                    }

                    // Only show navigation controls if we have multiple images
                    if sortedImages.count > 1 {
                        // Image counter indicator
                        Text("\(currentImageIndex + 1) / \(sortedImages.count)")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(8)

                        // Navigation arrows
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

                // Dots indicator for multiple images
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
}

// Extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    VStack(spacing: 20) {
        // YouTube Embed
        EmbedView(embed: PreviewData.youtubeEmbed)

        // Link Embed
        EmbedView(embed: PreviewData.linkEmbed)
    }
    .padding()
}
