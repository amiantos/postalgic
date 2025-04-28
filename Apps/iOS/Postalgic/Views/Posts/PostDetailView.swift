//
//  PostDetailView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI
struct PostDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var post: Post
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let title = post.title {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    if post.isDraft {
                        Spacer()
                        Text("DRAFT")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("PPink"))
                            .cornerRadius(8)
                    }
                }

                HStack {
                    Text(post.createdAt, format: .dateTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let category = post.category {
                        Spacer()
                        Text(category.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("PGreen"))
                            .cornerRadius(8)
                    }
                }

                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(post.tags) { tag in
                                Text(tag.name)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("PBlue"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Divider()
                
                // Display embed above content if present
                if let embed = post.embed, embed.embedPosition == .above {
                    EmbedView(embed: embed)
                        .padding(.bottom, 16)
                }

                Text(.init(post.content))
                    .textSelection(.enabled)
                    .font(.body)
                
                // Display embed below content if present
                if let embed = post.embed, embed.embedPosition == .below {
                    EmbedView(embed: embed)
                        .padding(.top, 16)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(post.title ?? "Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Text("Edit")
                }
                
                Button(action: { showingDeleteAlert = true }) {
                    Text("Delete")
                        .foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PostFormView(post: post)
        }
        .alert("Delete Post", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
    }
    
    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Regular Post") {
    PreviewData.withNavigationStack {
        PostDetailView(post: PreviewData.blogWithContent().posts.first!)
    }
    .modelContainer(PreviewData.previewContainer)
}

#Preview("Post with Embed") {
    PreviewData.withNavigationStack {
        let post = PreviewData.blogWithContent().posts[1]
        return PostDetailView(post: post)
    }
    .modelContainer(PreviewData.previewContainer)
}
