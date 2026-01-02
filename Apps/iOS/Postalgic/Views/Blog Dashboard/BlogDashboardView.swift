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
    @Environment(\.dismiss) private var dismiss
    var blog: Blog

    @State private var showingPostForm = false
    @State private var showingPublishView = false
    @State private var showingSettingsView = false
    @State private var showingPostsView = false

    // Sync on load state
    @State private var isCheckingSyncOnLoad = false
    @State private var showingSyncPrompt = false
    @State private var syncCheckResult: SyncCheckResult?
    @State private var isSyncingFromPrompt = false
    @State private var syncError: String?
    @State private var showingSyncError = false

    // Computed property for draft posts
    private var draftPosts: [Post] {
        return blog.posts.filter { $0.isDraft }.sorted { $0.createdAt > $1.createdAt }
    }

    // Computed property for recent published posts
    private var recentPublishedPosts: [Post] {
        return blog.posts.filter { !$0.isDraft }.sorted { $0.createdAt > $1.createdAt }.prefix(20).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Quick Actions Section
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            showingSettingsView = true
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 24))
                                Text("More")
                                    .font(.caption)
                            }.padding(3).frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                        }.buttonStyle(.bordered).foregroundStyle(.primary)

                        if let url = URL(string: blog.url) {
                            Button(action: {
                                UIApplication.shared.open(url)
                            }) {
                                VStack(spacing: 3) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 24))
                                    Text("Visit Site")
                                        .font(.caption)
                                }.padding(3).frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity
                                )
                            }.buttonStyle(.bordered).foregroundStyle(.primary)
                        }
                        
                        Button(action: { showingPublishView = true }) {
                            VStack(spacing: 3) {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 24))
                                Text("Publish")
                                    .font(.caption)
                            }.padding(3).frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                    }.padding(.horizontal)
                    
                    HStack(spacing: 12) {

                        NavigationLink {
                            PostsView(blog: blog)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "book.pages")
                                    .font(.system(size: 24))
                                Text("All Posts")
                                    .font(.caption)
                            }.padding(3).frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                        }.buttonStyle(.bordered).foregroundStyle(
                            .primary
                        )

                        Button(action: { showingPostForm = true }) {
                            VStack(spacing: 3) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 24))
                                Text("New Post")
                                    .font(.caption)
                            }.padding(3).frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                        }.buttonStyle(.borderedProminent).foregroundStyle(
                            .primary
                        )
                    }
                    .padding(.horizontal)
                }.dynamicTypeSize(...DynamicTypeSize.xLarge)

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
            
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    if let url = URL(string: "https://postalgic.app/help") {
                       UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
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
            BlogSettingsView(blog: blog) {
                dismiss()
            }
        }
        .sheet(isPresented: $showingPostsView) {
            PostsView(blog: blog)
        }
        .onAppear {
            checkForSyncChangesIfNeeded()
        }
        .alert("Changes Available", isPresented: $showingSyncPrompt) {
            Button("Sync Now") {
                performSync()
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Remote changes detected: \(syncCheckResult?.changeSummary ?? "updates available"). Would you like to sync now?")
        }
        .alert("Sync Error", isPresented: $showingSyncError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncError ?? "An unknown error occurred while syncing.")
        }
    }

    // MARK: - Sync on Load

    /// Checks for remote sync changes if conditions are met:
    /// - Sync is enabled on the blog
    /// - Blog has a URL configured
    /// - This blog hasn't been checked this session yet
    private func checkForSyncChangesIfNeeded() {
        guard blog.syncEnabled,
              !blog.url.isEmpty,
              !SyncSessionManager.shared.hasCheckedThisSession(blogId: blog.id.uuidString)
        else { return }

        isCheckingSyncOnLoad = true

        Task {
            do {
                let result = try await SyncChecker.checkForChanges(blog: blog)

                await MainActor.run {
                    SyncSessionManager.shared.markAsChecked(blogId: blog.id.uuidString)
                    isCheckingSyncOnLoad = false

                    if result.hasChanges {
                        syncCheckResult = result
                        showingSyncPrompt = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingSyncOnLoad = false
                    // Silent fail on load check - don't interrupt user flow
                    // They can manually sync if needed
                }
            }
        }
    }

    /// Performs the sync when user confirms the prompt
    private func performSync() {
        isSyncingFromPrompt = true

        Task {
            do {
                _ = try await IncrementalSync.pullChanges(
                    blog: blog,
                    modelContext: modelContext
                ) { _ in
                    // Progress updates could be shown in UI if desired
                }

                await MainActor.run {
                    isSyncingFromPrompt = false
                    syncCheckResult = nil
                }
            } catch {
                await MainActor.run {
                    isSyncingFromPrompt = false
                    syncError = error.localizedDescription
                    showingSyncError = true
                }
            }
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
