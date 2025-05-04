import SwiftUI
import UIKit
import SwiftData

struct EditPostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    // The post being edited
    let post: Post
    
    // The blog the post belongs to
    private var blog: Blog {
        return post.blog!
    }
    
    // Content state - initialized from the post
    @State private var title: String
    @State private var content: String
    @State private var isDraft: Bool
    
    // Categories and tags - initialized from the post
    @State private var selectedCategory: Category?
    @State private var selectedTags: [Tag] = []
    
    // Embed - initialized from the post
    @State private var embed: Embed?
    
    // UI State
    @State private var showURLPrompt: Bool = false
    @State private var urlText: String = ""
    @State private var urlLink: String = ""
    @State private var showingFullSettings: Bool = false
    @State private var showingCategoryManagement: Bool = false
    @State private var showingTagManagement: Bool = false
    @State private var showingEmbedForm: Bool = false
    @State private var showPublishView: Bool = false
    @State private var tagInput: String = ""
    @State private var showingSuggestions: Bool = false
    
    private var blogTags: [Tag] {
        return allTags.filter { $0.blog?.id == blog.id }
    }
    
    private var blogCategories: [Category] {
        return allCategories.filter { $0.blog?.id == blog.id }
    }
    
    private var filteredTags: [Tag] {
        if tagInput.isEmpty {
            return blogTags.sorted {
                $0.name.lowercased() < $1.name.lowercased()
            }
        } else {
            let lowercasedInput = tagInput.lowercased()
            return blogTags.filter {
                $0.name.lowercased().contains(lowercasedInput)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
    
    init(post: Post) {
        self.post = post
        
        // Initialize state from the post
        _title = State(initialValue: post.title ?? "")
        _content = State(initialValue: post.content)
        _isDraft = State(initialValue: post.isDraft)
        _selectedCategory = State(initialValue: post.category)
        _selectedTags = State(initialValue: post.tags)
        _embed = State(initialValue: post.embed)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main editing view (when not showing full settings)
                if !showingFullSettings {
                    VStack(spacing: 0) {
                        TextField("Title (optional)", text: $title)
                            .font(.title)
                            .padding()
                            .onChange(of: title) { _, newValue in
                                // Update post in real-time
                                post.title = newValue.isEmpty ? nil : newValue
                            }
                        
                        Divider()
                        
                        MarkdownTextEditor(text: $content, onShowLinkPrompt: { selectedText, selectedRange in
                            self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: content) { _, newValue in
                            // Update post in real-time
                            post.content = newValue
                        }
                    }
                    .navigationTitle("Edit Post")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // Leading toolbar items
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button("Done") {
                                // Just close the view - post already updated in real-time
                                post.regenerateStub()
                                dismiss()
                            }
                        }
                        
                        // Trailing toolbar items
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Menu {
                                Button(action: {
                                    showingFullSettings = true
                                }) {
                                    Label("Post Settings", systemImage: "gear")
                                }
                                
                                Button(action: {
                                    // Save as draft
                                    post.isDraft = true
                                    post.regenerateStub()
                                    dismiss()
                                }) {
                                    Label("Save as Draft", systemImage: "square.and.arrow.down")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button("Publish") {
                                // Ensure post is saved
                                post.title = title.isEmpty ? nil : title
                                post.content = content
                                post.isDraft = false
                                post.regenerateStub()
                                showPublishView = true
                            }
                        }
                    }
                }
                // Full settings view (when showingFullSettings is true)
                else {
                    SettingsContentView
                }
            }
        }
        .alert("Add Link", isPresented: $showURLPrompt) {
            TextField("Text", text: $urlText)
            TextField("URL", text: $urlLink)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                insertLink()
            }
        } message: {
            Text("Enter link details")
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(blog: blog)
        }
        .sheet(isPresented: $showingEmbedForm) {
            EmbedFormView(post: post) { updatedEmbed in 
                // The embed is automatically added to the post in EmbedFormView
                // Update our local state to match
                self.embed = updatedEmbed
            }
        }
        .sheet(isPresented: $showPublishView, onDismiss: {
            dismiss()
        }) {
            PublishBlogView(blog: blog, autoPublish: true)
        }
    }
    
    // Settings view content as a separate view builder
    @ViewBuilder
    private var SettingsContentView: some View {
        Form {
            Section("Content") {
                TextField("Title (optional)", text: $title)
                    .onChange(of: title) { _, newValue in
                        post.title = newValue.isEmpty ? nil : newValue
                    }
                
                NavigationLink(destination: 
                    VStack {
                        MarkdownTextEditor(text: $content, onShowLinkPrompt: { selectedText, selectedRange in
                            self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: content) { _, newValue in
                            post.content = newValue
                        }
                    }
                    .navigationTitle("Edit Content")
                ) {
                    VStack(alignment: .leading) {
                        Text("Content")
                            .font(.headline)
                        
                        if content.isEmpty {
                            Text("No content")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Text(content)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Embed Section
            Section("Embed") {
                if let embed = embed {
                    VStack(alignment: .leading, spacing: 12) {
                        // Embed info row
                        HStack {
                            Text("Type:").bold()
                            Text(embed.embedType.rawValue)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Position:").bold()
                            Text(embed.embedPosition.rawValue)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("URL:").bold()
                            Text(embed.url)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Buttons in separate rows for clarity
                        Button(action: {
                            showingEmbedForm = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Embed")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button(action: {
                            if let oldEmbed = post.embed {
                                modelContext.delete(oldEmbed)
                            }
                            post.embed = nil
                            embed = nil
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Embed")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                } else {
                    Button(action: {
                        showingEmbedForm = true
                    }) {
                        Label("Add Embed", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            
            // Category section
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(Category?.none)
                    
                    if !blogCategories.isEmpty {
                        Divider()
                        
                        ForEach(
                            blogCategories.sorted { $0.name < $1.name }
                        ) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                }
                .onChange(of: selectedCategory) { _, newCategory in
                    updatePostCategory(newCategory)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: {
                    showingCategoryManagement = true
                }) {
                    Text("Manage Categories")
                }
            }
            
            // Tags section
            Section("Tags") {
                HStack {
                    TextField("Add tags...", text: $tagInput)
                        .autocorrectionDisabled()
                        .onSubmit {
                            addTag()
                        }
                        .onChange(of: tagInput) { _, newValue in
                            // Keep the input lowercase while typing
                            let lowercased = newValue.lowercased()
                            if lowercased != newValue {
                                tagInput = lowercased
                            }
                            showingSuggestions = true
                        }
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(tagInput.isEmpty)
                }
                
                if showingSuggestions && !filteredTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(filteredTags) { tag in
                                Button(action: {
                                    if !selectedTags.contains(where: {
                                        $0.id == tag.id
                                    }) {
                                        selectedTags.append(tag)
                                        addTagToPost(tag)
                                    }
                                    tagInput = ""
                                    showingSuggestions = false
                                }) {
                                    Text(tag.name)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Color.secondary.opacity(0.2)
                                        )
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                if !selectedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedTags) { tag in
                                HStack(spacing: 5) {
                                    Text(tag.name)
                                    Button(action: {
                                        removeTagFromPost(tag)
                                        selectedTags.removeAll {
                                            $0.id == tag.id
                                        }
                                    }) {
                                        Image(
                                            systemName: "xmark.circle.fill"
                                        )
                                        .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("Post Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    showingFullSettings = false
                }
            }
        }
    }
    
    // Update post category relationship
    private func updatePostCategory(_ newCategory: Category?) {
        // Remove post from previous category
        if let oldCategory = post.category {
            if let index = oldCategory.posts.firstIndex(where: { $0.id == post.id }) {
                oldCategory.posts.remove(at: index)
            }
        }
        
        // Add to new category
        post.category = newCategory
        if let newCategory = newCategory {
            newCategory.posts.append(post)
        }
    }
    
    // Add tag to post
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !trimmed.isEmpty {
            // Check if tag already exists for this blog (case insensitive)
            if let existingTag = blogTags.first(where: {
                $0.name.lowercased() == trimmed
            }) {
                if !selectedTags.contains(where: { $0.id == existingTag.id }) {
                    selectedTags.append(existingTag)
                    addTagToPost(existingTag)
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(name: trimmed)
                modelContext.insert(newTag)
                newTag.blog = blog
                blog.tags.append(newTag)
                selectedTags.append(newTag)
                addTagToPost(newTag)
            }
            tagInput = ""
        }
    }
    
    private func addTagToPost(_ tag: Tag) {
        post.tags.append(tag)
        tag.posts.append(post)
    }
    
    private func removeTagFromPost(_ tag: Tag) {
        if let index = post.tags.firstIndex(where: { $0.id == tag.id }) {
            post.tags.remove(at: index)
        }
        
        if let index = tag.posts.firstIndex(where: { $0.id == post.id }) {
            tag.posts.remove(at: index)
        }
    }
    
    func handleShowLinkPrompt(selectedText: String?, selectedRange: NSRange?) {
        if let text = selectedText, !text.isEmpty {
            // Text is selected
            urlText = text
            
            // Check clipboard for URL
            if let clipboardString = UIPasteboard.general.string,
               let url = URL(string: clipboardString),
               UIApplication.shared.canOpenURL(url) {
                
                // Use clipboard URL
                urlLink = clipboardString
                insertLink()
            } else {
                // No URL in clipboard, show prompt for URL
                urlLink = ""
                showURLPrompt = true
            }
        } else {
            // No text selected, prompt for both text and URL
            urlText = ""
            urlLink = ""
            showURLPrompt = true
        }
    }
    
    func insertLink() {
        guard !urlText.isEmpty else { return }
        
        let markdownLink = "[\(urlText)](\(urlLink))"
        let notification = Notification(name: Notification.Name("InsertMarkdownLink"), 
                                        object: nil, 
                                        userInfo: ["text": markdownLink])
        NotificationCenter.default.post(notification)
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        EditPostView(post: blog.posts.first!)
    }
    .modelContainer(modelContainer)
}