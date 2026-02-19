//
//  RemoteImageEmbedView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct RemoteImageEmbedView: View {
    @Environment(\.dismiss) private var dismiss

    let existingEmbed: RemoteEmbed?
    let server: RemoteServer
    let blog: RemoteBlog
    let onSave: (RemoteEmbedData) -> Void

    @State private var position: String = "below"
    @State private var isProcessingImages = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var showingFilePicker = false

    private var isEditing: Bool { existingEmbed != nil }

    init(existingEmbed: RemoteEmbed? = nil, server: RemoteServer, blog: RemoteBlog, onSave: @escaping (RemoteEmbedData) -> Void) {
        self.existingEmbed = existingEmbed
        self.server = server
        self.blog = blog
        self.onSave = onSave

        if let embed = existingEmbed, embed.type == "image" {
            _position = State(initialValue: embed.position ?? "below")
            // Note: we can't reload existing image data from filenames alone for remote embeds
            // User will need to re-select images if editing
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Images")) {
                    VStack(spacing: 8) {
                        PhotosPicker(
                            selection: $selectedItems,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Select from Photos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("Select from Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onChange(of: selectedItems) { _, newValue in
                        Task {
                            if !newValue.isEmpty {
                                isProcessingImages = true
                                selectedImageData = []

                                for item in newValue {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
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
                                                Button {
                                                    selectedImageData.remove(at: index)
                                                    if index < selectedItems.count {
                                                        selectedItems.remove(at: index)
                                                    }
                                                } label: {
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

                if isEditing && selectedImageData.isEmpty {
                    Section {
                        if let images = existingEmbed?.images, !images.isEmpty {
                            Text("\(images.count) existing image\(images.count == 1 ? "" : "s"). Select new images above to replace them.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Position")) {
                    Picker("Position", selection: $position) {
                        Text("Above").tag("above")
                        Text("Below").tag("below")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Edit Image Embed" : "Add Image Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        saveEmbed()
                        dismiss()
                    }
                    .disabled(selectedImageData.isEmpty || isProcessingImages)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await handleFilePickerResult(result)
                }
            }
        }
    }

    private func saveEmbed() {
        var embedData = RemoteEmbedData(type: "image", url: "image://gallery", position: position)

        var imagesArray: [[String: Any]] = []
        for (index, imageData) in selectedImageData.enumerated() {
            let base64String = imageData.base64EncodedString()
            // Determine mime type (default to jpeg for optimized images)
            let mimeType = "image/jpeg"
            let dataUrl = "data:\(mimeType);base64,\(base64String)"

            imagesArray.append([
                "data": dataUrl,
                "filename": "image-\(index).jpg",
                "order": index
            ])
        }

        embedData.images = imagesArray
        onSave(embedData)
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            await MainActor.run { isProcessingImages = true }
            var newImageData: [Data] = []

            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }

                    do {
                        let data = try Data(contentsOf: url)
                        if let optimizedData = Utils.optimizeImage(imageData: data, maxDimension: 1024) {
                            newImageData.append(optimizedData)
                        }
                    } catch {
                        Log.error("Error reading file: \(error)")
                    }
                }
            }

            await MainActor.run {
                selectedImageData = newImageData
                selectedItems = [] // Clear photo picker selection
                isProcessingImages = false
            }

        case .failure(let error):
            Log.error("File picker error: \(error)")
        }
    }
}
