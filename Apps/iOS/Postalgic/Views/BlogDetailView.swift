//
//  BlogDetailView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct BlogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var blog: Blog
    @State private var showingPostForm = false
    
    var body: some View {
        List {
            let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
            ForEach(sortedPosts) { post in
                NavigationLink {
                    PostDetailView(post: post)
                } label: {
                    VStack(alignment: .leading) {
                        if let title = post.title {
                            Text(title)
                                .font(.headline)
                        } else {
                            Text(post.content.prefix(50))
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text(post.createdAt, format: .dateTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deletePosts)
        }
        .navigationTitle(blog.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: { showingPostForm = true }) {
                    Label("Add Post", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPostForm) {
            PostFormView(blog: blog)
        }
    }
    
    private func deletePosts(offsets: IndexSet) {
        withAnimation {
            let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
            for index in offsets {
                let postToDelete = sortedPosts[index]
                if let postIndex = blog.posts.firstIndex(where: { $0.id == postToDelete.id }) {
                    blog.posts.remove(at: postIndex)
                }
                modelContext.delete(postToDelete)
            }
        }
    }
}

#Preview {
    BlogDetailView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self, Post.self], inMemory: true)
}
