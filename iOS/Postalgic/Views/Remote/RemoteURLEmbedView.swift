//
//  RemoteURLEmbedView.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct RemoteURLEmbedView: View {
    @Environment(\.dismiss) private var dismiss

    let existingEmbed: RemoteEmbed?
    let onSave: (RemoteEmbedData) -> Void
    var onTitleUpdate: ((String) -> Void)?

    @State private var url: String = ""
    @State private var embedType: String = "link"
    @State private var position: String = "below"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkMetadata: (title: String?, description: String?, imageUrl: String?, imageData: Data?) = (nil, nil, nil, nil)
    @State private var youtubeTitle: String?
    @State private var hasCheckedClipboard = false

    private var isEditing: Bool { existingEmbed != nil }

    init(existingEmbed: RemoteEmbed? = nil, onSave: @escaping (RemoteEmbedData) -> Void, onTitleUpdate: ((String) -> Void)? = nil) {
        self.existingEmbed = existingEmbed
        self.onSave = onSave
        self.onTitleUpdate = onTitleUpdate

        if let embed = existingEmbed, embed.type == "youtube" || embed.type == "link" {
            _url = State(initialValue: embed.url ?? "")
            _embedType = State(initialValue: embed.type)
            _position = State(initialValue: embed.position ?? "below")

            if embed.type == "youtube" {
                _youtubeTitle = State(initialValue: embed.title)
            }
            if embed.type == "link" {
                _linkMetadata = State(initialValue: (
                    title: embed.title,
                    description: embed.description,
                    imageUrl: embed.imageUrl,
                    imageData: nil
                ))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Embed Type")) {
                    Picker("Type", selection: $embedType) {
                        Text("YouTube").tag("youtube")
                        Text("Link").tag("link")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("URL")) {
                    TextField("Enter URL", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: url) { _, _ in
                            linkMetadata = (nil, nil, nil, nil)
                            youtubeTitle = nil
                            errorMessage = nil
                        }

                    if !url.isEmpty {
                        if embedType == "link" {
                            Button("Fetch Link Metadata") {
                                fetchLinkMetadata()
                            }
                            .disabled(isLoading)
                        } else if embedType == "youtube" {
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
                            Spacer()
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if embedType == "youtube", let title = youtubeTitle {
                    Section(header: Text("YouTube Title")) {
                        Text(title)
                            .font(.headline)
                    }
                }

                // Set as post title
                Section(header: Text("Post Title")) {
                    let currentEmbedTitle: String? = embedType == "youtube" ? youtubeTitle : linkMetadata.title

                    if let title = currentEmbedTitle, !title.isEmpty {
                        Button("Set as Post Title") {
                            onTitleUpdate?(title)
                            saveEmbed()
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

                if embedType == "link", linkMetadata.title != nil {
                    Section(header: Text("Link Preview")) {
                        VStack(alignment: .leading) {
                            Text(linkMetadata.title ?? "")
                                .font(.headline)

                            if let description = linkMetadata.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if let imageUrl = linkMetadata.imageUrl, let imgURL = URL(string: imageUrl) {
                                AsyncImage(url: imgURL) { phase in
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
                        Text("Above").tag("above")
                        Text("Below").tag("below")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Edit URL Embed" : "Add URL Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        saveEmbed()
                        dismiss()
                    }
                    .disabled(url.isEmpty || isLoading)
                }
            }
            .onAppear {
                checkClipboard()
            }
        }
    }

    private func checkClipboard() {
        guard !hasCheckedClipboard && !isEditing else { return }

        if let clipboardString = UIPasteboard.general.string,
           let clipboardUrl = URL(string: clipboardString),
           UIApplication.shared.canOpenURL(clipboardUrl) {

            url = clipboardString

            if Utils.extractYouTubeId(from: clipboardString) != nil {
                embedType = "youtube"
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

    private func saveEmbed() {
        var embedData = RemoteEmbedData(type: embedType, url: url, position: position)

        if embedType == "youtube" {
            embedData.title = youtubeTitle
        } else if embedType == "link" {
            embedData.title = linkMetadata.title
            embedData.description = linkMetadata.description
            embedData.imageUrl = linkMetadata.imageUrl

            // Convert image data to base64 data URL for the API
            if let imageData = linkMetadata.imageData {
                embedData.imageData = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
            }
        }

        onSave(embedData)
    }
}

/// Data structure for embed data to be sent to the API
struct RemoteEmbedData {
    var type: String
    var url: String
    var position: String
    var title: String?
    var description: String?
    var imageUrl: String?
    var imageData: String? // base64 data URL
    var images: [[String: Any]]? // For image embeds

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "url": url,
            "position": position
        ]

        if let title { dict["title"] = title }
        if let description { dict["description"] = description }
        if let imageUrl { dict["imageUrl"] = imageUrl }
        if let imageData { dict["imageData"] = imageData }
        if let images { dict["images"] = images }

        return dict
    }
}
