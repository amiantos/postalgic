//
//  TextBlockFormView.swift
//  Postalgic
//
//  Created by Claude on 4/28/25.
//

import SwiftUI
import SwiftData

struct TextBlockFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    var sidebarObject: SidebarObject?
    
    @State private var title = ""
    @State private var content = ""
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Text Block")) {
                    TextField("Title", text: $title)
                }
                
                Section(header: Text("Content (Markdown supported)"), footer: Text("You can use Markdown formatting in your text block.")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle(sidebarObject == nil ? "Add Text Block" : "Edit Text Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTextBlock()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let sidebarObject = sidebarObject {
                    title = sidebarObject.title
                    content = sidebarObject.content ?? ""
                    isEditing = true
                }
            }
        }
    }
    
    private func saveTextBlock() {
        if isEditing, let sidebarObject = sidebarObject {
            // Update existing text block
            sidebarObject.title = title
            sidebarObject.content = content
        } else {
            // Create a new text block with the next available order
            let nextOrder = blog.sidebarObjects.count
            let newSidebarObject = SidebarObject(title: title, type: .text, order: nextOrder)
            newSidebarObject.content = content
            newSidebarObject.blog = blog
            blog.sidebarObjects.append(newSidebarObject)
        }
    }
}