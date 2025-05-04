import SwiftUI
import SwiftData

/// A simplified settings view specific for use with AddPostView
/// Creates its own post instance to avoid SwiftData synchronization issues
struct TempPostSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    // Pass this back to the parent view to update
    var onSave: ([Tag], Category?) -> Void
    
    // Blog reference
    let blog: Blog
    
    // Post content to initialize
    let title: String
    let content: String
    
    // Initial values to display
    let initialTags: [Tag]
    let initialCategory: Category?
    
    // State
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []
    @State private var selectedCategory: Category?
    @State private var showingCategoryManagement = false
    @State private var showingSuggestions = false
    
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
    
    init(
        blog: Blog,
        title: String,
        content: String,
        initialTags: [Tag] = [],
        initialCategory: Category? = nil,
        onSave: @escaping ([Tag], Category?) -> Void
    ) {
        self.blog = blog
        self.title = title
        self.content = content
        self.initialTags = initialTags
        self.initialCategory = initialCategory
        self.onSave = onSave
        
        // Initialize state
        _selectedTags = State(initialValue: initialTags)
        _selectedCategory = State(initialValue: initialCategory)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Post Preview
                Section("Post Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        if !title.isEmpty {
                            Text(title)
                                .font(.headline)
                        }
                        
                        if !content.isEmpty {
                            Text(content)
                                .lineLimit(3)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Empty post")
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Call the callback with the selected tags and category
                        onSave(selectedTags, selectedCategory)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView(blog: blog)
            }
        }
    }
    
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
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(name: trimmed)
                modelContext.insert(newTag)
                newTag.blog = blog
                blog.tags.append(newTag)
                selectedTags.append(newTag)
            }
            tagInput = ""
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        TempPostSettingsView(
            blog: blog,
            title: "Sample Post",
            content: "This is some sample content for the post.",
            onSave: { _, _ in }
        )
    }
    .modelContainer(modelContainer)
}