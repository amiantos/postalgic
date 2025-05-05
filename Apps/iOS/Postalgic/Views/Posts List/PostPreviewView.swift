//
//  PostPreviewView.swift
//  Postalgic
//
//  Created by Claude on 5/2/25.
//

import SwiftData
import SwiftUI

struct PostPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    let post: Post

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(formatDate(post.createdAt))
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 3)

            Text(post.displayTitle)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            
            if let embed = post.embed, embed.embedPosition == .above {
                EmbedView(embed: embed)
                    .padding(.top, 6)
            }

            Text(post.plainContent).multilineTextAlignment(
                .leading
            ).lineLimit(3).font(.subheadline).padding(.top, 6)
            
            if let embed = post.embed, embed.embedPosition == .below {
                EmbedView(embed: embed)
                    .padding(.top, 12)
            }

            if post.category != nil || !post.tags.isEmpty {
                HStack {
                    if let category = post.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                ).fill(.accent)
                            )
                            .lineLimit(1)
                    }

                    if !post.tags.isEmpty {
                        ForEach(post.tags.prefix(2)) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .foregroundStyle(
                                    Color.accentColor
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 8,
                                        style: .circular
                                    ).fill(Color("LYellow"))
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: 1
                                        )
                                )
                                .lineLimit(1)
                        }
                        if post.tags.count > 2 {
                            Text("+\(post.tags.count - 2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }.padding(.top, 12)
            }

            HStack {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Label {
                        Text("Delete")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                Button {
                    showingEditSheet = true
                } label: {
                    Label {
                        Text("Edit")
                    } icon: {
                        Image(systemName: "square.and.pencil")
                    }
                }.frame(maxWidth: .infinity)

                Divider()

                Button {
                    sharePost()
                } label: {
                    Label {
                        Text("Share")
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }.frame(maxWidth: .infinity)

            }.font(.subheadline).foregroundStyle(.secondary).padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background.secondary)
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingEditSheet) {
            PostView(post: post).interactiveDismissDisabled()
        }
        .alert("Delete Post", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text(
                "Are you sure you want to delete this post? This action cannot be undone."
            )
        }
    }

    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
    }

    private func sharePost() {
        // Create the share URL for the post
        if let blog = post.blog,
            let url = URL(string: "\(blog.url)/\(post.urlPath)")
        {
            let items: [Any] = [url]
            let activityVC = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            // Find the current key window to present the activity view controller
            if let windowScene = UIApplication.shared.connectedScenes.first
                as? UIWindowScene,
                let rootViewController = windowScene.windows.first?
                    .rootViewController
            {
                rootViewController.present(activityVC, animated: true)
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today, " + formatter.string(from: date)
        }

        if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday, " + formatter.string(from: date)
        }

        // For other dates
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
