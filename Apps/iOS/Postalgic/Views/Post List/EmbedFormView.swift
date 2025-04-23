//
//  EmbedFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import SwiftData
import SwiftUI

struct EmbedFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var post: Post
    @State private var url: String = ""
    @State private var embedType: EmbedType = .youtube
    @State private var position: EmbedPosition = .below
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkMetadata: (title: String?, description: String?, imageUrl: String?, imageData: Data?) = (nil, nil, nil, nil)
    
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
                    
                    if embedType == .link && !url.isEmpty {
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
            .navigationTitle("Add Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEmbed()
                        dismiss()
                    }
                    .disabled(url.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func addEmbed() {
        // Create new embed
        let embed = Embed(
            url: url,
            type: embedType,
            position: position,
            title: linkMetadata.title,
            embedDescription: linkMetadata.description,
            imageUrl: linkMetadata.imageUrl,
            imageData: linkMetadata.imageData
        )
        
        // Insert embed into model context
        modelContext.insert(embed)
        
        // Remove any existing embed
        if let oldEmbed = post.embed {
            modelContext.delete(oldEmbed)
        }
        
        // Associate with post
        post.embed = embed
        embed.post = post
    }
}

#Preview {
    @State var post = Post(title: "Test Post", content: "Test content")
    
    return EmbedFormView(post: $post)
        .modelContainer(for: [Post.self, Embed.self], inMemory: true)
}