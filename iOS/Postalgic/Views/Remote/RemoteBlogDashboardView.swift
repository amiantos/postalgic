//
//  RemoteBlogDashboardView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteBlogDashboardView: View {
    let server: RemoteServer
    let blog: RemoteBlog

    @State private var stats: RemoteBlogStats?
    @State private var recentPosts: [RemotePost] = []
    @State private var draftPosts: [RemotePost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingNewPost = false
    @State private var showingPublish = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Failed to load blog")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadData()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(alignment: .leading, spacing: 30) {
                    // Quick Actions
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            if let url = URL(string: blog.url) {
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: "safari")
                                            .font(.system(size: 24))
                                        Text("Visit Site")
                                            .font(.caption)
                                    }
                                    .padding(3)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .foregroundStyle(.primary)
                            }

                            NavigationLink {
                                RemotePostsView(server: server, blog: blog)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "book.pages")
                                        .font(.system(size: 24))
                                    Text("All Posts")
                                        .font(.caption)
                                }
                                .padding(3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)

                            Button {
                                showingNewPost = true
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 24))
                                    Text("New Post")
                                        .font(.caption)
                                }
                                .padding(3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)

                        HStack(spacing: 12) {
                            NavigationLink {
                                RemoteCategoryManagementView(server: server, blogId: blog.id)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 24))
                                    Text("Categories")
                                        .font(.caption)
                                }
                                .padding(3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)

                            NavigationLink {
                                RemoteTagManagementView(server: server, blogId: blog.id)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 24))
                                    Text("Tags")
                                        .font(.caption)
                                }
                                .padding(3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)

                            Button {
                                showingPublish = true
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 24))
                                    Text("Publish")
                                        .font(.caption)
                                }
                                .padding(3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)

                    // Stats
                    if let stats {
                        HStack(spacing: 16) {
                            StatBadge(label: "Posts", value: stats.publishedPosts)
                            StatBadge(label: "Drafts", value: stats.draftPosts)
                            StatBadge(label: "Categories", value: stats.totalCategories)
                            StatBadge(label: "Tags", value: stats.totalTags)
                        }
                        .padding(.horizontal)
                    }

                    // Draft Posts
                    if !draftPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Draft Posts")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            ForEach(draftPosts) { post in
                                RemotePostPreviewView(post: post, server: server, blog: blog, onChanged: {
                                    loadData()
                                })
                            }
                        }
                    }

                    // Recent Posts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Posts")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if recentPosts.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "doc")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                    Text("No published posts")
                                        .font(.headline)
                                    Button("Create your first post") {
                                        showingNewPost = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.vertical, 30)
                                Spacer()
                            }
                        } else {
                            ForEach(recentPosts) { post in
                                RemotePostPreviewView(post: post, server: server, blog: blog, onChanged: {
                                    loadData()
                                })
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(blog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingNewPost = true
                } label: {
                    Label("New Post", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPost) {
            RemotePostView(server: server, blog: blog, onSave: {
                loadData()
            })
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingPublish) {
            RemotePublishView(server: server, blog: blog)
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            if isLoading {
                loadData()
            }
        }
    }

    private func loadData() {
        isLoading = true
        errorMessage = nil

        Task {
            await refreshData()
        }
    }

    private func refreshData() async {
        let client = PostalgicAPIClient(server: server)

        do {
            async let statsTask = client.fetchBlogStats(blogId: blog.id)
            async let publishedTask = client.fetchPosts(blogId: blog.id, status: "published", limit: 20)
            async let draftsTask = client.fetchPosts(blogId: blog.id, status: "drafts", limit: 10)

            let (fetchedStats, publishedResponse, draftsResponse) = try await (statsTask, publishedTask, draftsTask)

            await MainActor.run {
                stats = fetchedStats
                recentPosts = publishedResponse.posts
                draftPosts = draftsResponse.posts
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
