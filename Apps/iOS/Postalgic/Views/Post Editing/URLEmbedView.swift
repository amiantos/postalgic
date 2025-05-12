import SwiftUI
import SwiftData

struct URLEmbedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var post: Post
    var onTitleUpdate: ((String) -> Void)?

    @State private var url: String = ""
    @State private var embedType: EmbedType = .link
    @State private var position: EmbedPosition = .below
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkMetadata: (title: String?, description: String?, imageUrl: String?, imageData: Data?) = (nil, nil, nil, nil)
    @State private var youtubeTitle: String?
    @State private var isEditing: Bool = false

    // Check clipboard on appearing
    @State private var hasCheckedClipboard = false

    init(post: Post, onTitleUpdate: ((String) -> Void)? = nil) {
        self.post = post
        self.onTitleUpdate = onTitleUpdate

        // Check if we're editing an existing embed
        if let embed = post.embed, (embed.embedType == .youtube || embed.embedType == .link) {
            _url = State(initialValue: embed.url)
            _embedType = State(initialValue: embed.embedType)
            _position = State(initialValue: embed.embedPosition)
            _isEditing = State(initialValue: true)

            // Pre-populate title for YouTube embeds
            if embed.embedType == .youtube {
                _youtubeTitle = State(initialValue: embed.title)
            }

            // Pre-populate metadata for Link embeds
            if embed.embedType == .link {
                _linkMetadata = State(initialValue: (
                    title: embed.title,
                    description: embed.embedDescription,
                    imageUrl: embed.imageUrl,
                    imageData: embed.imageData
                ))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Embed Type")) {
                    Picker("Type", selection: $embedType) {
                        ForEach([EmbedType.youtube, EmbedType.link], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("URL")) {
                    TextField("Enter URL", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .onChange(of: url) { oldValue, newValue in
                            // Reset metadata when URL changes
                            if oldValue != newValue {
                                linkMetadata = (nil, nil, nil, nil)
                                youtubeTitle = nil
                                errorMessage = nil
                            }
                        }
                    
                    if !url.isEmpty {
                        if embedType == .link {
                            Button("Fetch Link Metadata") {
                                fetchLinkMetadata()
                            }
                            .disabled(isLoading)
                        } else if embedType == .youtube {
                            Button("Fetch YouTube Title") {
                                fetchYouTubeTitle()
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Spacer()
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                // Show YouTube title if available
                if embedType == .youtube && youtubeTitle != nil {
                    Section(header: Text("YouTube Title")) {
                        Text(youtubeTitle ?? "")
                            .font(.headline)
                    }
                }
                
                // Button to set embed title as post title
                Section(header: Text("Post Title")) {
                    let currentEmbedTitle: String? = {
                        if embedType == .youtube {
                            return youtubeTitle
                        } else if embedType == .link {
                            return linkMetadata.title
                        }
                        return nil
                    }()
                    
                    if let title = currentEmbedTitle, !title.isEmpty {
                        Button("Set as Post Title") {
                            onTitleUpdate?(title)
                            if isEditing {
                                updateEmbed()
                            } else {
                                addEmbed()
                            }
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("No embed title available")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                // Show preview for Link embeds
                if embedType == .link && linkMetadata.title != nil {
                    Section(header: Text("Link Preview")) {
                        VStack(alignment: .leading) {
                            Text(linkMetadata.title ?? "")
                                .font(.headline)
                            
                            if let description = linkMetadata.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let imageUrl = linkMetadata.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 200)
                                    case .failure:
                                        Image(systemName: "photo")
                                            .imageScale(.large)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                
                Section(header: Text("Position")) {
                    Picker("Position", selection: $position) {
                        ForEach([EmbedPosition.above, EmbedPosition.below], id: \.self) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Edit URL Embed" : "Add URL Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        if isEditing {
                            updateEmbed()
                        } else {
                            addEmbed()
                        }
                        dismiss()
                    }
                    .disabled(url.isEmpty || isLoading)
                }
            }
        }
        .onAppear {
            checkClipboard()
        }
    }
    
    private func checkClipboard() {
        // Skip clipboard check if we're editing an existing embed
        guard !hasCheckedClipboard && !isEditing else { return }

        if let clipboardString = UIPasteboard.general.string,
           let clipboardUrl = URL(string: clipboardString),
           UIApplication.shared.canOpenURL(clipboardUrl) {

            url = clipboardString

            // If it looks like a YouTube URL, change embed type to YouTube
            if Utils.extractYouTubeId(from: clipboardString) != nil {
                embedType = .youtube
                fetchYouTubeTitle()
            } else {
                fetchLinkMetadata()
            }
        }

        hasCheckedClipboard = true
    }
    
    private func fetchLinkMetadata() {
        Task {
            isLoading = true
            errorMessage = nil
            linkMetadata = await LinkMetadataService.fetchMetadata(for: url)
            isLoading = false
            
            if linkMetadata == (nil, nil, nil, nil) {
                errorMessage = "Could not fetch metadata for this link"
            }
        }
    }
    
    private func fetchYouTubeTitle() {
        Task {
            isLoading = true
            errorMessage = nil
            youtubeTitle = await LinkMetadataService.fetchYouTubeTitle(for: url)
            isLoading = false
            
            if youtubeTitle == nil {
                errorMessage = "Could not fetch YouTube title"
            }
        }
    }
    
    private func addEmbed() {
        // Remove any existing embed
        if let oldEmbed = post.embed {
            modelContext.delete(oldEmbed)
        }

        // Create new embed
        let embed = Embed(
            post: post,
            url: url,
            type: embedType,
            position: position,
            title: embedType == .youtube ? youtubeTitle : linkMetadata.title,
            embedDescription: linkMetadata.description,
            imageUrl: linkMetadata.imageUrl,
            imageData: linkMetadata.imageData
        )
        
        post.embed = embed
        // Insert embed into model context
        modelContext.insert(embed)
    }

    private func updateEmbed() {
        guard let existingEmbed = post.embed else {
            // If for some reason the embed is gone, create a new one
            addEmbed()
            return
        }

        // Is it a type change?
        let isTypeChange = existingEmbed.embedType != embedType

        if isTypeChange {
            // If the type changed, it's safer to delete and create a new one
            modelContext.delete(existingEmbed)

            // Create a new embed
            let newEmbed = Embed(
                post: post,
                url: url,
                type: embedType,
                position: position,
                title: embedType == .youtube ? youtubeTitle : linkMetadata.title,
                embedDescription: linkMetadata.description,
                imageUrl: linkMetadata.imageUrl,
                imageData: linkMetadata.imageData
            )
            
            post.embed = newEmbed
            modelContext.insert(newEmbed)
        } else {
            // Update the existing embed's properties
            existingEmbed.url = url
            existingEmbed.position = position.rawValue

            if embedType == .youtube {
                existingEmbed.title = youtubeTitle
                existingEmbed.embedDescription = nil
                existingEmbed.imageUrl = nil
                existingEmbed.imageData = nil
            } else if embedType == .link {
                existingEmbed.title = linkMetadata.title
                existingEmbed.embedDescription = linkMetadata.description
                existingEmbed.imageUrl = linkMetadata.imageUrl
                existingEmbed.imageData = linkMetadata.imageData
            }
        }
    }
}

#Preview {
    NavigationStack {
        URLEmbedView(post: PreviewData.post) { title in
            print("Update post title to: \(title)")
        }
    }
    .modelContainer(PreviewData.previewContainer)
}
