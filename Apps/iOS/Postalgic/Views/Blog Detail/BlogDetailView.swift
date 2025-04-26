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
    @State private var showingTagManagement = false
    @State private var showingPublishSettingsView = false

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
                        PostRowView(post: post)
                    }
                }
            }
        }
        .navigationTitle(blog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingPostForm = true }) {
                    Label("Add Post", systemImage: "plus")
                }
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action:{
                    if let url = URL(string: blog.url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Visit Blog", systemImage: "safari")
                }
                Button(action: { showingEditBlogView = true }) {
                    Label("Blog Details", systemImage: "person")
                }
                
                Divider()
                
                Button(action: { showingPublishView = true }) {
                    Label("Publish", systemImage: "paperplane")
                }
                Button(action: { showingPublishSettingsView = true }) {
                    Label("Publishing Settings", systemImage: "paperplane.circle")
                }
                
                Divider()
                
                Button(action: {
                    showingCategoryManagement = true
                }) {
                    Label("Manage Categories", systemImage: "folder")
                }
                Button(action: {
                    showingTagManagement = true
                }) {
                    Label("Manage Tags", systemImage: "tag")
                }
            }
        }
        .sheet(isPresented: $showingPostForm) {
            PostFormView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingPublishView) {
            PublishBlogView(blog: blog)
        }
        .sheet(isPresented: $showingEditBlogView) {
            BlogFormView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(blog: blog)
        }
        .sheet(isPresented: $showingPublishSettingsView) {
            PublishSettingsView(blog: blog)
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        // Fetch the first blog from the container to ensure it's properly in the context
        BlogDetailView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}
