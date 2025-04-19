//
//  PostFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct PostFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    
    @State private var title = ""
    @State private var content = ""
    @State private var primaryLink = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Details") {
                    TextField("Title (optional)", text: $title)
                    TextField("Primary Link (optional)", text: $primaryLink)
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addPost()
                        dismiss()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
    }
    
    private func addPost() {
        let newPost = Post(
            title: title.isEmpty ? nil : title,
            content: content,
            primaryLink: primaryLink.isEmpty ? nil : primaryLink
        )
        modelContext.insert(newPost)
        blog.posts.append(newPost)
    }
}

#Preview {
    PostFormView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self, Post.self], inMemory: true)
}
