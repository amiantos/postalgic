//
//  PostsView.swift
//  Postalgic
//
//  Created by Claude on 5/2/25.
//

import SwiftData
import SwiftUI

struct PostsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    
    // Search state
    @State private var searchText = ""
    
    // Sort state
    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (newest)"
        case dateOldest = "Date (oldest)"
        case titleAZ = "Title (A-Z)"
        case titleZA = "Title (Z-A)"
    }

    @State private var sortOption = SortOption.dateNewest
    @State private var showingSortMenu = false
    @State private var showingPostForm = false
    
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

            // Toolbar with sort options
            HStack {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            sortOption = option
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort: \(sortOption.rawValue)")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(.background.secondary)
                    .foregroundStyle(.primary)
                    .cornerRadius(8)
                }

                Spacer()

                Text("\(filteredPosts.count) posts")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)

            // Posts list
            ScrollView {
                if filteredPosts.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredPosts) { post in
                            PostPreviewView(post: post)
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
                    showingPostForm = true
                } label: {
                    Label("New Post", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPostForm) {
            PostView(blog: blog).interactiveDismissDisabled()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("No posts found")
                    .font(.headline)
                
                Text("This blog doesn't have any posts yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
    }
    
    private var filteredPosts: [Post] {
        // First filter the posts based on search text
        let filtered: [Post]

        if searchText.isEmpty {
            filtered = blog.posts
        } else {
            // Search in title, content, category name, and tag names
            filtered = blog.posts.filter { post in
                // Check title
                if let title = post.title,
                   title.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Check content
                if post.content.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Check category
                if let category = post.category,
                   category.name.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Check tags
                for tag in post.tags {
                    if tag.name.localizedCaseInsensitiveContains(searchText) {
                        return true
                    }
                }
                
                return false
            }
        }
        
        // Then sort the filtered posts based on the current sort option
        return filtered.sorted { first, second in
            switch sortOption {
            case .dateNewest:
                return first.createdAt > second.createdAt
            case .dateOldest:
                return first.createdAt < second.createdAt
            case .titleAZ:
                return (first.title ?? first.content) < (second.title ?? second.content)
            case .titleZA:
                return (first.title ?? first.content) > (second.title ?? second.content)
            }
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        PostsView(
            blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
        )
    }
    .modelContainer(modelContainer)
}
