//
//  BlogFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct BlogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var url = ""
    
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
            .navigationTitle("New Blog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addBlog()
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
}

#Preview {
    BlogFormView()
        .modelContainer(for: [Blog.self], inMemory: true)
}
