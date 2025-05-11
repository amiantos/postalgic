//
//  BlogDashboardView.swift
//  Postalgic
//
//  Created by Claude on 5/1/25.
//

import SwiftData
import SwiftUI

struct BlogDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    var blog: Blog

    @State private var showingPostForm = false
    @State private var showingPublishView = false
    @State private var showingSettingsView = false
    @State private var showingPostsView = false

    // Query for all blog posts, sorted by creation date
    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]

    // Computed property for draft posts
    private var draftPosts: [Post] {
        return allPosts.filter { $0.isDraft && $0.blog == blog }
    }

    // Computed property for recent published posts
    private var recentPublishedPosts: [Post] {
        return allPosts.filter { !$0.isDraft && $0.blog == blog }.prefix(20).map
        { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Quick Actions Section
                VStack(spacing: 8) {
                    Button {
                        showingPostForm = true
                    } label: {
                        Label("New Post", systemImage: "square.and.pencil")
                            .padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }.buttonStyle(.borderedProminent).foregroundStyle(.primary).padding(.horizontal)
                    
                    Button {
                        showingPublishView = true
                    } label: {
                        Label("Publish", systemImage: "paperplane")
                            .padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }.buttonStyle(.bordered).foregroundStyle(.primary).padding(.horizontal)
                    
                    NavigationLink {
                        PostsView(blog: blog)
                    } label: {
                        Label("Posts", systemImage: "text.page").padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }.buttonStyle(.bordered).foregroundStyle(.primary).padding(.horizontal)
                    
                    Button {
                        if let url = URL(string: blog.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Visit Blog", systemImage: "safari")
                            .padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }.buttonStyle(.bordered).foregroundStyle(.primary).padding(.horizontal)
                    
                    NavigationLink {
                        BlogSettingsView(blog: blog)
                    } label: {
                        Label("Blog Settings", systemImage: "gear")
                            .padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }.buttonStyle(.bordered).foregroundStyle(.primary).padding(.horizontal)
                }

                // Draft Posts Section
                if !draftPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Draft Posts")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        ForEach(draftPosts) { post in
                            PostPreviewView(post: post)
                        }
                    }
                }

                // Recent Posts Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Posts")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)

                    if recentPublishedPosts.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)

                                Text("No published posts")
                                    .font(.headline)

                                Button(action: { showingPostForm = true }) {
                                    Text("Create your first post")
                                }.buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 30)
                            Spacer()
                        }
                    } else {
                        ForEach(recentPublishedPosts) { post in
                            PostPreviewView(post: post)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(blog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingPostForm = true
                } label: {
                    Label("New Post", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPostForm) {
            PostView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingPublishView) {
            PublishBlogView(blog: blog)
        }
        .sheet(isPresented: $showingSettingsView) {
            BlogSettingsView(blog: blog)
        }
        .sheet(isPresented: $showingPostsView) {
            PostsView(blog: blog)
        }
    }

}


#Preview {
    let modelContainer = PreviewData.previewContainer

    return NavigationStack {
        BlogDashboardView(
            blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>())
                .first!
        )
    }
    .modelContainer(modelContainer)
}
