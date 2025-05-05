import SwiftUI
import SwiftData

struct NewPostSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    var blog: Blog
    @Binding var draft: PostDraft
    @State private var tempEmbed: EmbedDraft?
    @State private var tagInput = ""
    @State private var showingSuggestions = false
    @State private var showingCategoryManagement = false
    @State private var showingEmbedForm = false
    
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Settings") {
                    Toggle("Save as Draft", isOn: $draft.isDraft)
                }
                
                Section("Embed") {
                    if let embed = draft.embed {
                        VStack(alignment: .leading, spacing: 12) {
                            // Embed info row
                            HStack {
                                Text("Type:").bold()
                                Text(embed.type.rawValue)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Position:").bold()
                                Text(embed.position.rawValue)
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
                                // Make a new EmbedDraft from the existing one to ensure it's a clean copy
                                tempEmbed = EmbedDraft(
                                    url: embed.url,
                                    type: embed.type,
                                    position: embed.position,
                                    title: embed.title,
                                    embedDescription: embed.embedDescription,
                                    imageUrl: embed.imageUrl,
                                    imageData: embed.imageData
                                )
                                print("Setting tempEmbed for editing: \(embed.url), Type: \(embed.type.rawValue)")
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
                                draft.embed = nil
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
                            // Create a temporary embed draft if needed
                            if tempEmbed == nil {
                                tempEmbed = EmbedDraft(
                                    url: "",
                                    type: .link, 
                                    position: .below
                                )
                                print("Created new empty tempEmbed")
                            } else {
                                print("Using existing tempEmbed: \(tempEmbed!.url)")
                            }
                            showingEmbedForm = true
                        }) {
                            Label("Add Embed", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
                
                Section("Category") {
                    Picker("Category", selection: $draft.category) {
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
                                        if !draft.tags.contains(where: {
                                            $0.id == tag.id
                                        }) {
                                            draft.tags.append(tag)
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
                    
                    if !draft.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(draft.tags) { tag in
                                    HStack(spacing: 5) {
                                        Text(tag.name)
                                        Button(action: {
                                            draft.tags.removeAll {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView(blog: blog)
            }
            .sheet(isPresented: $showingEmbedForm) {
                if let embed = tempEmbed {
                    EmbedDraftView(embed: embed) { embedTitle, savedEmbed in
                        // Update the post title with the embed title if requested
                        if !embedTitle.isEmpty && draft.title == nil {
                            draft.title = embedTitle
                        }
                        
                        // Set the embed to the draft
                        if let savedEmbed = savedEmbed {
                            draft.embed = savedEmbed
                            print("Saved embed to draft: \(savedEmbed.url), Type: \(savedEmbed.type.rawValue)")
                        } else {
                            print("No savedEmbed returned")
                        }
                        print("Setting tempEmbed to nil")
                        tempEmbed = nil
                    }
                }
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
                if !draft.tags.contains(where: { $0.id == existingTag.id }) {
                    draft.tags.append(existingTag)
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(name: trimmed)
                modelContext.insert(newTag)
                newTag.blog = blog
                blog.tags.append(newTag)
                draft.tags.append(newTag)
            }
            tagInput = ""
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    var draft = PostDraft()
    
    return NewPostSettingsView(blog: blog, draft: .constant(draft))
        .modelContainer(modelContainer)
}