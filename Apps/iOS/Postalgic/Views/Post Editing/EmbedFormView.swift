//
//  EmbedFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import SwiftData
import SwiftUI
import PhotosUI
// Define a struct to pass back to parent view
struct EmbedTitleUpdate {
    let title: String
}

struct EmbedFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var post: Post // Direct reference to the post
    var onTitleUpdate: ((String) -> Void)? // Callback for updating post title
    
    @State private var url: String = ""
    @State private var embedType: EmbedType = .youtube
    @State private var position: EmbedPosition = .below
    @State private var isEditing: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkMetadata: (title: String?, description: String?, imageUrl: String?, imageData: Data?) = (nil, nil, nil, nil)
    @State private var youtubeTitle: String? = nil

    // For image picker
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var isProcessingImages = false
    
    init(post: Post, onTitleUpdate: ((String) -> Void)? = nil) {
        self.post = post
        self.onTitleUpdate = onTitleUpdate
        
        if let embed = post.embed {
            // Initialize with existing embed values for editing
            _url = State(initialValue: embed.url)
            _embedType = State(initialValue: embed.embedType)
            _position = State(initialValue: embed.embedPosition)
            _isEditing = State(initialValue: true)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Embed Type")) {
                    Picker("Type", selection: $embedType) {
                        ForEach([EmbedType.youtube, EmbedType.link, EmbedType.image], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing && post.embed?.embedType != embedType)
                }
                
                // URL section for YouTube and Link embeds
                if embedType != .image {
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
                            let shouldShowFetchButton = !isEditing || (isEditing && post.embed?.url != url)

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
                }

                // Image picker section for Image embeds
                if embedType == .image {
                    Section(header: Text("Select Images")) {
                        PhotosPicker(
                            selection: $selectedItems,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Select Photos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedItems) { oldValue, newValue in
                            Task {
                                if !newValue.isEmpty {
                                    isProcessingImages = true
                                    selectedImageData = []

                                    for item in newValue {
                                        if let data = try? await item.loadTransferable(type: Data.self) {
                                            // Optimize the image
                                            if let optimizedData = Utils.optimizeImage(imageData: data) {
                                                selectedImageData.append(optimizedData)
                                            }
                                        }
                                    }

                                    isProcessingImages = false
                                }
                            }
                        }

                        if isProcessingImages {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Processing images...")
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }

                        // Display selected images
                        if !selectedImageData.isEmpty {
                            Text("Selected Photos: \(selectedImageData.count)")
                                .font(.headline)
                                .padding(.top, 8)

                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(0..<selectedImageData.count, id: \.self) { index in
                                        if let uiImage = UIImage(data: selectedImageData[index]) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                                .overlay(
                                                    Button(action: {
                                                        selectedImageData.remove(at: index)
                                                        selectedItems.remove(at: index)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Color.black.opacity(0.7))
                                                            .clipShape(Circle())
                                                    }
                                                    .padding(4),
                                                    alignment: .topTrailing
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .frame(height: 120)
                        }
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
                            return youtubeTitle ?? (isEditing ? post.embed?.title : nil)
                        } else if embedType == .link {
                            if linkMetadata.title != nil {
                                return linkMetadata.title
                            } else if isEditing, let embed = post.embed {
                                return embed.title
                            }
                        }
                        return nil
                    }()
                    
                    if let title = currentEmbedTitle, !title.isEmpty {
                        Button("Set as Post Title") {
                            // Call the callback to update the title in the parent view
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
                if embedType == .link {
                    // For new or edited link
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
                    // For existing embed that we're editing
                    else if isEditing, 
                            let embed = post.embed, 
                            embed.embedType == .link,
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
    }
    
    private func addEmbed() {
        // Remove any existing embed
        if let oldEmbed = post.embed {
            modelContext.delete(oldEmbed)
        }

        // For image embeds, create a placeholder URL
        let embedUrl = embedType == .image ? "image://gallery" : url

        // Create new embed
        let embed = Embed(
            post: post,
            url: embedUrl,
            type: embedType,
            position: position,
            title: embedType == .youtube ? youtubeTitle : linkMetadata.title,
            embedDescription: linkMetadata.description,
            imageUrl: linkMetadata.imageUrl,
            imageData: linkMetadata.imageData
        )

        // Insert embed into model context
        modelContext.insert(embed)
        post.embed = embed

        // For image embeds, add all selected images
        if embedType == .image && !selectedImageData.isEmpty {
            for (index, imageData) in selectedImageData.enumerated() {
                let filename = Utils.generateImageFilename(for: embed, order: index)
                let embedImage = EmbedImage(
                    embed: embed,
                    imageData: imageData,
                    order: index,
                    filename: filename
                )
                modelContext.insert(embedImage)
                embed.images.append(embedImage)
            }
        }
    }
    
    private func updateEmbed() {
        guard let existingEmbed = post.embed else {
            // If for some reason the embed is gone, create a new one instead
            addEmbed()
            return
        }

        // Check if this is a change in embed type
        let isTypeChange = existingEmbed.embedType != embedType
        let isUrlChange = existingEmbed.url != url && embedType != .image

        // For type changes, we create a new embed entirely
        if isTypeChange {
            // Delete the old embed first (this will cascade delete related embed images)
            modelContext.delete(existingEmbed)

            // For image embeds, create a placeholder URL
            let embedUrl = embedType == .image ? "image://gallery" : url

            // Create a new embed with the new type
            let newEmbed = Embed(
                post: post,
                url: embedUrl,
                type: embedType,
                position: position,
                title: embedType == .youtube ? youtubeTitle : nil
            )

            modelContext.insert(newEmbed)
            post.embed = newEmbed

            // If changing to Link type and we have metadata, add it
            if embedType == .link && linkMetadata != (nil, nil, nil, nil) {
                newEmbed.title = linkMetadata.title
                newEmbed.embedDescription = linkMetadata.description
                newEmbed.imageUrl = linkMetadata.imageUrl
                newEmbed.imageData = linkMetadata.imageData
            }

            // If changing to Image type and we have images, add them
            if embedType == .image && !selectedImageData.isEmpty {
                for (index, imageData) in selectedImageData.enumerated() {
                    let filename = Utils.generateImageFilename(for: newEmbed, order: index)
                    let embedImage = EmbedImage(
                        embed: newEmbed,
                        imageData: imageData,
                        order: index,
                        filename: filename
                    )
                    modelContext.insert(embedImage)
                    newEmbed.images.append(embedImage)
                }
            }
        } else if embedType == .image {
            // Update existing Image embed
            existingEmbed.position = position.rawValue

            // If we have new images, replace all existing ones
            if !selectedImageData.isEmpty {
                // Remove all existing images
                for image in existingEmbed.images {
                    modelContext.delete(image)
                }
                existingEmbed.images = []

                // Add new images
                for (index, imageData) in selectedImageData.enumerated() {
                    let filename = Utils.generateImageFilename(for: existingEmbed, order: index)
                    let embedImage = EmbedImage(
                        embed: existingEmbed,
                        imageData: imageData,
                        order: index,
                        filename: filename
                    )
                    modelContext.insert(embedImage)
                    existingEmbed.images.append(embedImage)
                }
            }
        } else {
            // For same type (non-image), just update properties
            existingEmbed.url = url
            existingEmbed.position = position.rawValue

            // Update YouTube title if we have one
            if embedType == .youtube && youtubeTitle != nil && existingEmbed.title != youtubeTitle {
                existingEmbed.title = youtubeTitle
            }

            // If URL changed for a Link type, update metadata if we have new metadata
            if isUrlChange && embedType == .link && linkMetadata != (nil, nil, nil, nil) {
                existingEmbed.title = linkMetadata.title
                existingEmbed.embedDescription = linkMetadata.description
                existingEmbed.imageUrl = linkMetadata.imageUrl
                existingEmbed.imageData = linkMetadata.imageData
            }
        }
    }
}

#Preview("New Embed") {
    NavigationStack {
        EmbedFormView(post: PreviewData.post) { title in
            print("Update post title to: \(title)")
        }
    }
    .modelContainer(PreviewData.previewContainer)
}

#Preview("Edit YouTube Embed") {
    NavigationStack {
        // Get a post with a YouTube embed from our preview data
        let post = PreviewData.blogWithContent().posts.first!
        return EmbedFormView(post: post) { title in
            print("Update post title to: \(title)")
        }
    }
    .modelContainer(PreviewData.previewContainer)
}

#Preview("Edit Link Embed") {
    NavigationStack {
        // Get a post with a Link embed from our preview data
        let post = PreviewData.blogWithContent().posts[1]
        return EmbedFormView(post: post) { title in
            print("Update post title to: \(title)")
        }
    }
    .modelContainer(PreviewData.previewContainer)
}
