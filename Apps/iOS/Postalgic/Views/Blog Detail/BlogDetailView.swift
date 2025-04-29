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
    
    // Initialized in init with proper fetch descriptor
    @Query private var allPosts: [Post]
    
    // Computed property for date-grouped posts
    private var postsByDate: [Date: [Post]] {
        let filteredPosts = allPosts.filter { post in
            // First filter by blog
            guard post.blog?.id == blog.id else { return false }
            
            // Then filter by selected filter type
            switch selectedFilter {
            case .all: return true
            case .published: return !post.isDraft
            case .drafts: return post.isDraft
            }
        }
        
        return Dictionary(grouping: filteredPosts) { post in
            Calendar.current.startOfDay(for: post.createdAt)
        }
    }
    
    // Sorted dates for display
    private var sortedDates: [Date] {
        postsByDate.keys.sorted(by: >)
    }
    @State private var showingPublishView = false
    @State private var showingEditBlogView = false
    @State private var showingCategoryManagement = false
    @State private var showingTagManagement = false
    @State private var showingSidebarManagement = false
    @State private var showingPublishSettingsView = false
    @State private var showingTemplateCustomizationView = false
    @State private var showingDeleteAlert = false
    @State private var deleteConfirmationText = ""
    @Environment(\.dismiss) private var dismiss

    enum PostFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case published = "Published"
        case drafts = "Drafts"

        var id: String { self.rawValue }
    }

    @State private var selectedFilter: PostFilter = .all
    
    init(blog: Blog) {
        self.blog = blog
        
        // Create a sorted fetch descriptor
        let sortDescriptor = SortDescriptor<Post>(\.createdAt, order: .reverse)
        let descriptor = FetchDescriptor<Post>(sortBy: [sortDescriptor])
        
        // Initialize the query with the descriptor
        self._allPosts = Query(descriptor)
    }

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
            
            if postsByDate.isEmpty {
                List{
                    VStack(alignment: .leading) {
                        Text("No \(selectedFilter.rawValue.lowercased()) posts yet")
                            .font(.headline)
                        
                        Text("Create your first post by tapping the + button, or, you know, the button right below this text.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: { showingPostForm = true }) {
                        Text("Create Post")
                    }
                }
            } else {
                List {
                    ForEach(sortedDates, id: \.self) { date in
                        Section(header: Text(formatDate(date))) {
                            ForEach(postsByDate[date]!) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                } label: {
                                    PostRowView(post: post, showDate: true)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(blog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingPostForm = true }) {
                    Label("Add Post", systemImage: "plus")
                }

                Menu {
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
                        Label("Publishing Settings", systemImage: "gear")
                    }
                    Button(action: { showingTemplateCustomizationView.toggle() }) {
                        Label("Customize Template", systemImage: "richtext.page")
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
                    
                    Button(action: {
                        showingSidebarManagement = true
                    }) {
                        Label("Manage Sidebar", systemImage: "sidebar.left")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete Blog", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
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
        .sheet(isPresented: $showingTemplateCustomizationView) {
            TemplateCustomizationView(blog: blog).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingSidebarManagement) {
            SidebarManagementView(blog: blog)
        }
        .alert("Delete Blog", isPresented: $showingDeleteAlert) {
            TextField("Type 'delete' to confirm", text: $deleteConfirmationText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            
            Button("Delete", role: .destructive) {
                if deleteConfirmationText.lowercased() == "delete" {
                    deleteBlog()
                }
                deleteConfirmationText = ""
            }
            .disabled(deleteConfirmationText.lowercased() != "delete")
        } message: {
            Text("This will permanently delete the blog '\(blog.name)' and all its posts.\n\nTo confirm, type 'delete' in the field below.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check if date is today
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        
        // Check if date is yesterday
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        // Check if date is in the current week
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let dateWeek = Calendar.current.component(.weekOfYear, from: date)
        let dateYear = Calendar.current.component(.year, from: date)
        let currentYear = Calendar.current.component(.year, from: Date())
        
        if dateWeek == currentWeek && dateYear == currentYear {
            formatter.dateFormat = "EEEE" // Day name (e.g., "Monday")
            return formatter.string(from: date)
        }
        
        // Current year but not current week
        if dateYear == currentYear {
            formatter.dateFormat = "MMMM d" // Month and day (e.g., "April 15")
            return formatter.string(from: date)
        }
        
        // Different year
        formatter.dateFormat = "MMMM d, yyyy" // Full date (e.g., "April 15, 2024")
        return formatter.string(from: date)
    }
    
    private func deleteBlog() {
        modelContext.delete(blog)
        try? modelContext.save()
        dismiss()
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
