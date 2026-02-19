//
//  RemotePostPreviewView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemotePostPreviewView: View {
    let post: RemotePost
    let server: RemoteServer
    let blog: RemoteBlog

    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading) {
            // Date
            Text(post.formattedDate ?? formatDate(post.createdAt))
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 3)

            // Title
            if post.title != nil {
                Text(post.displayTitle ?? post.title ?? "")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }

            // Content excerpt
            if !post.content.isEmpty {
                Text(post.excerpt ?? String(post.content.prefix(280)))
                    .font(.subheadline)
                    .lineLimit(6)
                    .padding(.top, 6)
            }

            // Category & Tags
            if post.category != nil || !(post.tags ?? []).isEmpty {
                HStack {
                    if let category = post.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.accent)
                            )
                            .lineLimit(1)
                    }

                    if let tags = post.tags, !tags.isEmpty {
                        ForEach(tags.prefix(2), id: \.id) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .circular)
                                        .fill(Color("LYellow"))
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                                .lineLimit(1)
                        }
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 12)
            }

            // Draft indicator
            if post.isDraft {
                Text("DRAFT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }

            // Actions
            HStack {
                if let urlPath = post.urlPath, !blog.url.isEmpty,
                   let url = URL(string: "\(blog.url)/\(urlPath)") {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("View", systemImage: "safari")
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider()

                Button {
                    sharePost()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity)
            }
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background.secondary)
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func sharePost() {
        guard let urlPath = post.urlPath, !blog.url.isEmpty,
              let url = URL(string: "\(blog.url)/\(urlPath)") else { return }

        let items: [Any] = [url]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        if let date = iso8601.date(from: dateString) {
            return Self.fullDateFormatter.string(from: date)
        }

        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) {
            return Self.fullDateFormatter.string(from: date)
        }

        return dateString
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()
}
