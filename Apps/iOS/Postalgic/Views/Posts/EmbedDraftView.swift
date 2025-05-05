import SwiftUI
import SwiftData

struct EmbedDraftView: View {
    @Environment(\.dismiss) private var dismiss
    
    var embed: EmbedDraft
    var onUpdate: ((String, EmbedDraft?) -> Void)
    
    @State private var url: String = ""
    @State private var embedType: EmbedType = .youtube
    @State private var position: EmbedPosition = .below
    @State private var isEditing: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkMetadata: (title: String?, description: String?, imageUrl: String?, imageData: Data?) = (nil, nil, nil, nil)
    @State private var youtubeTitle: String? = nil
    
    init(embed: EmbedDraft, onUpdate: @escaping (String, EmbedDraft?) -> Void) {
        self.embed = embed
        self.onUpdate = onUpdate
        
        print("Initializing EmbedDraftView with URL: \(embed.url), Type: \(embed.type)")
        
        // Initialize with existing embed values
        _url = State(initialValue: embed.url)
        _embedType = State(initialValue: embed.type) 
        _position = State(initialValue: embed.position)
        _isEditing = State(initialValue: !embed.url.isEmpty)
        _youtubeTitle = State(initialValue: embed.type == .youtube ? embed.title : nil)
        
        // Initialize link metadata from existing embed if it's a link type
        if embed.type == .link {
            _linkMetadata = State(initialValue: (
                title: embed.title,
                description: embed.embedDescription,
                imageUrl: embed.imageUrl,
                imageData: embed.imageData
            ))
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
                    .disabled(isEditing && embed.type != embedType)
                }
                
                Section(header: Text("URL")) {
                    TextField("Enter URL", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    // For Link type, show fetch button when appropriate
                    if embedType == .link && !url.isEmpty {
                        // Show fetch button if:
                        // 1. New embed or
                        // 2. Editing and URL changed from original
                        let shouldShowFetchButton = !isEditing || (isEditing && embed.url != url)
                        
                        if shouldShowFetchButton {
                            Button("Fetch Link Metadata") {
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
                            .disabled(isLoading)
                        }
                    } else if embedType == .youtube && !url.isEmpty {
                        // Show fetch title button for YouTube embeds
                        Button("Fetch YouTube Title") {
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
                        .disabled(isLoading)
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
                            return youtubeTitle ?? (isEditing ? embed.title : nil)
                        } else if embedType == .link {
                            if linkMetadata.title != nil {
                                return linkMetadata.title
                            } else if isEditing {
                                return embed.title
                            }
                        }
                        return nil
                    }()
                    
                    if let title = currentEmbedTitle, !title.isEmpty {
                        Button("Set as Post Title") {
                            // Create updated embed and pass back the title
                            let updatedEmbed = createUpdatedEmbed()
                            print("Set as Post Title: passing back title '\(title)' and embed: \(updatedEmbed.url)")
                            onUpdate(title, updatedEmbed)
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
                if embedType == .link {
                    // For new or edited link with fresh metadata
                    if linkMetadata.title != nil {
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
                    // For existing temporary embed that we're editing
                    else if isEditing,
                            embed.type == .link,
                            linkMetadata == (nil, nil, nil, nil) { // Only if we haven't fetched new metadata
                        
                        Section(header: Text("Current Link Preview")) {
                            VStack(alignment: .leading) {
                                if let title = embed.title {
                                    Text(title)
                                        .font(.headline)
                                }
                                
                                if let description = embed.embedDescription {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let imageData = embed.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .padding(.top, 8)
                                } else if let imageUrl = embed.imageUrl, let url = URL(string: imageUrl) {
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
            .navigationTitle(isEditing ? "Edit Embed" : "Add Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        let updatedEmbed = createUpdatedEmbed()
                        print("Toolbar action: passing back updated embed: \(updatedEmbed.url)")
                        onUpdate("", updatedEmbed)
                        dismiss()
                    }
                    .disabled(url.isEmpty || isLoading)
                }
            }
        }
    }
    
    // Create an updated EmbedDraft with current form values
    private func createUpdatedEmbed() -> EmbedDraft {
        var updatedEmbed = EmbedDraft(
            url: url,
            type: embedType,
            position: position
        )
        
        if embedType == .youtube {
            updatedEmbed.title = youtubeTitle
            print("Creating YouTube embed: \(url) with title: \(youtubeTitle ?? "nil")")
        } else if embedType == .link {
            if linkMetadata != (nil, nil, nil, nil) {
                // Use fresh metadata if available
                updatedEmbed.title = linkMetadata.title
                updatedEmbed.embedDescription = linkMetadata.description
                updatedEmbed.imageUrl = linkMetadata.imageUrl
                updatedEmbed.imageData = linkMetadata.imageData
                print("Creating Link embed with fresh metadata: \(url), title: \(linkMetadata.title ?? "nil")")
            } else if isEditing && url == embed.url {
                // Keep original metadata if URL hasn't changed
                updatedEmbed.title = embed.title
                updatedEmbed.embedDescription = embed.embedDescription
                updatedEmbed.imageUrl = embed.imageUrl
                updatedEmbed.imageData = embed.imageData
                print("Keeping original metadata for Link embed: \(url), title: \(embed.title ?? "nil")")
            } else {
                print("WARNING: No metadata for Link embed: \(url)")
            }
        }
        
        return updatedEmbed
    }
}

#Preview("New Embed") {
    let embed = EmbedDraft()
    
    return EmbedDraftView(embed: embed) { title, updatedEmbed in
        print("Title: \(title), Embed URL: \(updatedEmbed?.url ?? "none")")
    }
}

#Preview("Edit YouTube Embed") {
    let embed = EmbedDraft(
        url: "https://www.youtube.com/watch?v=1234567890",
        type: .youtube,
        position: .below,
        title: "Sample YouTube Video"
    )
    
    return EmbedDraftView(embed: embed) { title, updatedEmbed in
        print("Title: \(title), Embed URL: \(updatedEmbed?.url ?? "none")")
    }
}

#Preview("Edit Link Embed") {
    let embed = EmbedDraft(
        url: "https://apple.com",
        type: .link,
        position: .above,
        title: "Apple",
        embedDescription: "Apple Inc. official website",
        imageUrl: "https://www.apple.com/ac/structured-data/images/open_graph_logo.png"
    )
    
    return EmbedDraftView(embed: embed) { title, updatedEmbed in
        print("Title: \(title), Embed URL: \(updatedEmbed?.url ?? "none")")
    }
}