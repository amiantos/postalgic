import SwiftUI
import SwiftData
import PhotosUI

struct ImageEmbedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var post: Post

    @State private var position: EmbedPosition = .above
    @State private var isProcessingImages = false
    @State private var isEditing: Bool = false

    // For image picker
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []

    init(post: Post) {
        self.post = post

        // Check if we're editing an existing image embed
        if let embed = post.embed, embed.embedType == .image {
            _position = State(initialValue: embed.embedPosition)
            _isEditing = State(initialValue: true)

            // Load existing images
            let sortedImages = embed.images.sorted { $0.order < $1.order }
            _selectedImageData = State(initialValue: sortedImages.map { $0.imageData })
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Images")) {
                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(selectedImageData.isEmpty ? "Select Photos" : "Change Photos", systemImage: "photo.on.rectangle")
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
                                        // Optimize the image (constrained to 1024 pixels max dimension)
                                        if let optimizedData = Utils.optimizeImage(imageData: data, maxDimension: 1024) {
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
                                                    // Only remove from selectedItems if it's within bounds
                                                    if index < selectedItems.count {
                                                        selectedItems.remove(at: index)
                                                    }
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
                
                Section(header: Text("Position")) {
                    Picker("Position", selection: $position) {
                        ForEach([EmbedPosition.above, EmbedPosition.below], id: \.self) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Edit Image Embed" : "Add Image Embed")
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
                    .disabled(selectedImageData.isEmpty || isProcessingImages)
                }
            }
        }
    }
    
    private func addEmbed() {
        // Remove any existing embed
        if let oldEmbed = post.embed {
            modelContext.delete(oldEmbed)
        }

        // Create new embed with placeholder URL
        let embed = Embed(
            post: post,
            url: "image://gallery",
            type: .image,
            position: position
        )

        // Insert embed into model context
        modelContext.insert(embed)
        post.embed = embed

        // Add all selected images to the embed
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

    private func updateEmbed() {
        guard let existingEmbed = post.embed, existingEmbed.embedType == .image else {
            // If for some reason the embed is gone or not an image embed, create a new one
            addEmbed()
            return
        }

        // Update position
        existingEmbed.position = position.rawValue

        // Remove all existing images
        for image in existingEmbed.images {
            modelContext.delete(image)
        }
        existingEmbed.images = []

        // Add all selected images to the embed
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
}

#Preview {
    NavigationStack {
        ImageEmbedView(post: PreviewData.post)
    }
    .modelContainer(PreviewData.previewContainer)
}
