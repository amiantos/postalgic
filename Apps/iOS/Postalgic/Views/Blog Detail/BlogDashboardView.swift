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
    @State private var showingCategoryManagement = false
    @State private var showingTagManagement = false
    
    
    // Query for all blog posts, sorted by creation date
    @Query private var allPosts: [Post]
    
    // Computed property for draft posts
    private var draftPosts: [Post] {
        return allPosts.filter { $0.isDraft && $0.blog == blog }
    }
    
    // Computed property for recent published posts
    private var recentPublishedPosts: [Post] {
        return allPosts.filter { !$0.isDraft  && $0.blog == blog }.prefix(5).map { $0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Quick Actions Section
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: { showingSettingsView = true }) {
                            VStack(spacing:3) {
                                Image(systemName: "richtext.page").font(.system(size: 24))
                                Text("Appearance").font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                        
                        Button(action: { showingCategoryManagement = true }) {
                            VStack(spacing:3) {
                                Image(systemName: "folder").font(.system(size: 24))
                                Text("Categories").font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                        
                        Button(action: { showingTagManagement = true }) {
                            VStack(spacing:3) {
                                Image(systemName: "tag").font(.system(size: 24))
                                Text("Tags").font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                    }.padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: { if let url = URL(string: blog.url) {
                            UIApplication.shared.open(url)
                        } }) {
                            VStack(spacing:3) {
                                Image(systemName: "safari")
                                    .font(.system(size: 24))
                                Text("Visit Site")
                                    .font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                        
                        Button(action: { showingPublishView = true }) {
                            VStack(spacing:3) {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 24))
                                Text("Publish Now")
                                    .font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).foregroundStyle(.primary)
                        
                        Button(action: { showingPostForm = true }) {
                            VStack(spacing:3) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 24))
                                Text("New Post")
                                    .font(.caption)
                            }.padding(3).frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).foregroundStyle(.primary)
                    }
                    .padding(.horizontal)
                }
                
                // Draft Posts Section
                if !draftPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                    Text("Draft Posts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    
                        ForEach(draftPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        
                                        Text(formatDate(post.createdAt))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(post.displayTitle)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }.padding(3)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Recent Posts Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Posts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        NavigationLink(destination: BlogDetailView(blog: blog)) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
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
                            NavigationLink(destination: PostDetailView(post: post)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formatDate(post.createdAt))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(post.displayTitle)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }.padding(3)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.primary)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(blog.name)
        .sheet(isPresented: $showingPostForm) {
            PostFormView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingPublishView) {
            PublishBlogView(blog: blog)
        }
        .sheet(isPresented: $showingSettingsView) {
            BlogSettingsView(blog: blog)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(blog: blog)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today, " + formatter.string(from: date)
        }
        
        if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday, " + formatter.string(from: date)
        }
        
        // For other dates
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
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
