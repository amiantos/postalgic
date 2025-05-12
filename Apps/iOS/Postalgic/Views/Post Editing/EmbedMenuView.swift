import SwiftUI

struct EmbedMenuView: View {
    @Environment(\.dismiss) private var dismiss
    
    var post: Post
    var onTitleUpdate: ((String) -> Void)?
    
    @State private var showURLEmbed = false
    @State private var showImageEmbed = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        showURLEmbed = true
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Add URL")
                                    .font(.headline)
                                Text("Embed YouTube videos or website links")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        showImageEmbed = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Add Images")
                                    .font(.headline)
                                Text("Embed one or more images from your photo library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Embed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showURLEmbed) {
                URLEmbedView(post: post, onTitleUpdate: onTitleUpdate)
                    .onDisappear {
                        dismiss() // Dismiss the menu after URL embed view is closed
                    }
            }
            .sheet(isPresented: $showImageEmbed) {
                ImageEmbedView(post: post)
                    .onDisappear {
                        dismiss() // Dismiss the menu after image embed view is closed
                    }
            }
        }
    }
}

#Preview {
    EmbedMenuView(post: PreviewData.post) { title in
        print("Update post title to: \(title)")
    }
}