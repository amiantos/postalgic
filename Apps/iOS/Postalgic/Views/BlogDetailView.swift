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
    @State private var showingPublishView = false
    @State private var showingEditBlogView = false
    @State private var showingCategoryManagement = false
    
    var body: some View {
        List {
            let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
            ForEach(sortedPosts) { post in
                NavigationLink {
                    PostDetailView(post: post)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = post.title {
                            Text(title)
                                .font(.headline)
                        } else {
                            Text(post.content.prefix(50))
                                .font(.headline)
                                .lineLimit(1)
                        }
                        HStack {
                            Text(post.createdAt, format: .dateTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let category = post.category {
                                Spacer()
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            }
                        }
                        
                        if !post.tags.isEmpty {
                            HStack {
                                ForEach(post.tags.prefix(3)) { tag in
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                if post.tags.count > 3 {
                                    Text("+\(post.tags.count - 3)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditBlogView = true }) {
                        Label("Edit Blog", systemImage: "pencil")
                    }
                    Button(action: { showingPublishView = true }) {
                        Label("Publish", systemImage: "globe")
                    }
                    Divider()
                    Button(action: { 
                        showingCategoryManagement = true 
                    }) {
                        Label("Manage Categories", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
        .sheet(isPresented: $showingPublishView) {
            PublishBlogView(blog: blog)
        }
        .sheet(isPresented: $showingEditBlogView) {
            EditBlogView(blog: blog)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
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
        .modelContainer(for: [Blog.self, Post.self, Tag.self, Category.self], inMemory: true)
}