//
//  BlogDetailView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct BlogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var blog: Blog
    @State private var showingPostForm = false
    @State private var showingPublishView = false
    @State private var showingEditBlogView = false
    @State private var showingCategoryManagement = false

    enum PostFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case published = "Published"
        case drafts = "Drafts"

        var id: String { self.rawValue }
    }

    @State private var selectedFilter: PostFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(PostFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            List {
                let filteredPosts = blog.posts
                    .filter { post in
                        switch selectedFilter {
                        case .all: return true
                        case .published: return !post.isDraft
                        case .drafts: return post.isDraft
                        }
                    }
                    .sorted { $0.createdAt > $1.createdAt }

                ForEach(filteredPosts) { post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if let title = post.title {
                                    Text(title)
                                        .font(.headline)
                                } else {
                                    Text(post.content.prefix(50))
                                        .font(.headline)
                                        .lineLimit(1)
                                }

                                if post.isDraft {
                                    Spacer()
                                    Text("DRAFT")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color("PPink"))
                                        .cornerRadius(4)
                                }
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
                                        .background(Color("PGreen"))
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
                                            .background(Color("PBlue"))
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
        }
        .navigationTitle(blog.name)
        .toolbarTitleMenu {
            Button("All Posts (\(blog.posts.count))") {
                selectedFilter = .all
            }
            Button("Published (\(blog.posts.filter { !$0.isDraft }.count))") {
                selectedFilter = .published
            }
            Button("Drafts (\(blog.posts.filter { $0.isDraft }.count))") {
                selectedFilter = .drafts
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingPostForm = true }) {
                        Label("Add Post", systemImage: "plus")
                    }
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
        }
        .sheet(isPresented: $showingPostForm) {
            PostFormView(blog: blog)
        }
        .sheet(isPresented: $showingPublishView) {
            PublishBlogView(blog: blog)
        }
        .sheet(isPresented: $showingEditBlogView) {
            BlogFormView(blog: blog)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
    }

    private func deletePosts(offsets: IndexSet) {
        withAnimation {
            let filteredPosts = blog.posts
                .filter { post in
                    switch selectedFilter {
                    case .all: return true
                    case .published: return !post.isDraft
                    case .drafts: return post.isDraft
                    }
                }
                .sorted { $0.createdAt > $1.createdAt }

            for index in offsets {
                let postToDelete = filteredPosts[index]
                if let postIndex = blog.posts.firstIndex(where: {
                    $0.id == postToDelete.id
                }) {
                    blog.posts.remove(at: postIndex)
                }
                modelContext.delete(postToDelete)
            }
        }
    }
}

#Preview {
    BlogDetailView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(
            for: [Blog.self, Post.self, Tag.self, Category.self],
            inMemory: true
        )
}
