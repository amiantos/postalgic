//
//  RemotePostsView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemotePostsView: View {
    let server: RemoteServer
    let blog: RemoteBlog

    @State private var posts: [RemotePost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Pagination
    @State private var currentPage = 1
    @State private var hasMore = false
    @State private var totalCount = 0
    @State private var isLoadingMore = false

    // New post
    @State private var showingNewPost = false

    // Search & filter
    @State private var searchText = ""
    @State private var statusFilter = "all"
    @State private var sortOption = "date_desc"

    // Debounce search
    @State private var searchTask: Task<Void, Never>?

    enum SortOption: String, CaseIterable {
        case dateNewest = "date_desc"
        case dateOldest = "date_asc"
        case titleAZ = "title_asc"
        case titleZA = "title_desc"

        var displayName: String {
            switch self {
            case .dateNewest: return "Date (newest)"
            case .dateOldest: return "Date (oldest)"
            case .titleAZ: return "Title (A-Z)"
            case .titleZA: return "Title (Z-A)"
            }
        }
    }

    var body: some View {
        VStack {
            // Search bar
            TextField("Search posts", text: $searchText)
                .padding(10)
                .background(.background.secondary)
                .foregroundStyle(.primary)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: searchText) { _, _ in
                    debounceSearch()
                }

            // Sort & filter toolbar
            HStack {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option.rawValue
                            resetAndLoad()
                        } label: {
                            HStack {
                                Text(option.displayName)
                                if sortOption == option.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort: \(SortOption(rawValue: sortOption)?.displayName ?? "Date")")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(.background.secondary)
                    .foregroundStyle(.primary)
                    .cornerRadius(8)
                }

                Spacer()

                Text("\(totalCount) posts")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)

            // Status filter
            Picker("Status", selection: $statusFilter) {
                Text("All").tag("all")
                Text("Published").tag("published")
                Text("Drafts").tag("drafts")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: statusFilter) { _, _ in
                resetAndLoad()
            }

            // Posts list
            ScrollView {
                if isLoading && posts.isEmpty {
                    ProgressView("Loading posts...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorMessage, posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            resetAndLoad()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else if posts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        if searchText.isEmpty {
                            Text("No posts found")
                                .font(.headline)
                        } else {
                            Text("No matching posts")
                                .font(.headline)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding()
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(posts) { post in
                            RemotePostPreviewView(post: post, server: server, blog: blog, onChanged: {
                                    resetAndLoad()
                                })
                        }

                        if hasMore {
                            Button {
                                loadMore()
                            } label: {
                                if isLoadingMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Load More")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                            .disabled(isLoadingMore)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("All Posts")
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
                resetAndLoad()
            })
            .interactiveDismissDisabled()
        }
        .refreshable {
            await refreshPosts()
        }
        .onAppear {
            if isLoading {
                resetAndLoad()
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            if !Task.isCancelled {
                await MainActor.run {
                    resetAndLoad()
                }
            }
        }
    }

    private func resetAndLoad() {
        currentPage = 1
        posts = []
        isLoading = true
        errorMessage = nil

        Task {
            await fetchPosts(page: 1, replace: true)
        }
    }

    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true

        Task {
            await fetchPosts(page: currentPage + 1, replace: false)
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }

    private func refreshPosts() async {
        await fetchPosts(page: 1, replace: true)
    }

    private func fetchPosts(page: Int, replace: Bool) async {
        let client = PostalgicAPIClient(server: server)

        do {
            let response = try await client.fetchPosts(
                blogId: blog.id,
                status: statusFilter,
                search: searchText,
                sort: sortOption,
                page: page,
                limit: 20
            )

            await MainActor.run {
                if replace {
                    posts = response.posts
                } else {
                    posts.append(contentsOf: response.posts)
                }
                currentPage = response.page
                hasMore = response.hasMore
                totalCount = response.total
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
