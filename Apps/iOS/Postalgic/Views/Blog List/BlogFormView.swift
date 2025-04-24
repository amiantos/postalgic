//
//  BlogFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct BlogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Determines if we're creating a new blog or editing an existing one
    private var isEditing: Bool
    
    // Optional blog for editing mode
    private var blog: Blog?
    
    @State private var name: String
    @State private var url: String
    
    // Initialize for creating a new blog
    init() {
        self.isEditing = false
        self.blog = nil
        _name = State(initialValue: "")
        _url = State(initialValue: "")
    }
    
    // Initialize for editing an existing blog
    init(blog: Blog) {
        self.isEditing = true
        self.blog = blog
        _name = State(initialValue: blog.name)
        _url = State(initialValue: blog.url)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Details") {
                    TextField("Name", text: $name)
                    TextField("URL", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }
            }
            .navigationTitle(isEditing ? "Edit Blog" : "New Blog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing {
                            updateBlog()
                        } else {
                            addBlog()
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func addBlog() {
        let newBlog = Blog(name: name, url: url)
        modelContext.insert(newBlog)
    }
    
    private func updateBlog() {
        if let blogToUpdate = blog {
            blogToUpdate.name = name
            blogToUpdate.url = url
        }
    }
}

#Preview {
    BlogFormView()
        .modelContainer(for: [Blog.self], inMemory: true)
}

#Preview {
    BlogFormView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self], inMemory: true)
}