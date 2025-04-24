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
            }
        }
    }
}

struct YouTubeEmbedView: View {
    var embed: Embed
    @State private var videoId: String?
    
    var body: some View {
        ZStack {
            if let videoId = extractYouTubeId(from: embed.url) {
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
    
    private func extractYouTubeId(from url: String) -> String? {
        let patterns = [
            // youtu.be URLs
            "youtu\\.be\\/([a-zA-Z0-9_-]{11})",
            // youtube.com/watch?v= URLs
            "youtube\\.com\\/watch\\?v=([a-zA-Z0-9_-]{11})",
            // youtube.com/embed/ URLs
            "youtube\\.com\\/embed\\/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
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

#Preview("Standalone Embeds") {
    NavigationStack {
        VStack(spacing: 20) {
            // YouTube Embed using standalone entity
            EmbedView(embed: PreviewData.youtubeEmbed)
            
            // Link Embed using standalone entity
            EmbedView(embed: PreviewData.linkEmbed)
        }
        .padding()
    }
}

#Preview("Container-Based Embeds") {
    PreviewBuilder.containerPreview(
        entity: { 
            // Create a VStack containing both embeds
            VStack(spacing: 20) {
                if let youtubeEmbed = PreviewData.previewEmbed(at: 0) {
                    EmbedView(embed: youtubeEmbed)
                }
                
                if let linkEmbed = PreviewData.previewEmbed(at: 1) {
                    EmbedView(embed: linkEmbed)
                }
            }
            .padding()
        },
        content: { content in
            content
        }
    )
}