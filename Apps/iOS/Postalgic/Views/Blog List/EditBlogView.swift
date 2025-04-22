//
//  EditBlogView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

struct EditBlogView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var blog: Blog

    @State private var name: String
    @State private var url: String

    init(blog: Blog) {
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
            .navigationTitle("Edit Blog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateBlog()
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }

    private func updateBlog() {
        blog.name = name
        blog.url = url
    }
}

#Preview {
    EditBlogView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self], inMemory: true)
}
