//
//  TextBlockFormView.swift
//  Postalgic
//
//  Created by Claude on 4/28/25.
//

import SwiftUI
import SwiftData
import Ink

struct AddTextBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    
    @State private var title = ""
    @State private var content = ""
    
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
            .navigationTitle("Add Text Block")
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
        }
    }
    
    private func saveTextBlock() {
        // Render markdown to HTML (trimmed to match Self-Hosted behavior)
        let markdownParser = MarkdownParser()
        let contentHtml = markdownParser.html(from: content).trimmingCharacters(in: .whitespacesAndNewlines)

        // Create a new text block with the next available order
        let nextOrder = blog.sidebarObjects.count
        let newSidebarObject = SidebarObject(blog: blog, title: title, type: .text, order: nextOrder, contentHtml: contentHtml)
        newSidebarObject.content = content
        blog.sidebarObjects.append(newSidebarObject)
    }
}

struct EditTextBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    
    @Bindable var blog: Blog
    @Bindable var sidebarObject: SidebarObject
    
    @State private var title: String
    @State private var content: String
    @State private var hasChanges = false
    
    init(sidebarObject: SidebarObject, blog: Blog) {
        self.sidebarObject = sidebarObject
        self.blog = blog
        _title = State(initialValue: sidebarObject.title)
        _content = State(initialValue: sidebarObject.content ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Text Block")) {
                TextField("Title", text: $title)
                    .onChange(of: title) { _, _ in
                        checkForChanges()
                    }
            }
            
            Section(header: Text("Content (Markdown supported)"), footer: Text("You can use Markdown formatting in your text block.")) {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
                    .onChange(of: content) { _, _ in
                        checkForChanges()
                    }
            }
        }
        .navigationTitle("Edit Text Block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveTextBlock()
                    dismiss()
                }
                .disabled(title.isEmpty || !hasChanges)
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: presentationMode.wrappedValue.isPresented) { wasPresented, isPresented in
            if wasPresented && !isPresented && hasChanges {
                // The view is being dismissed, but we have unsaved changes
                // This is handled by interactiveDismissDisabled now
            }
        }
    }
    
    private func checkForChanges() {
        hasChanges = title != sidebarObject.title || 
                    content != (sidebarObject.content ?? "")
    }
    
    private func saveTextBlock() {
        // Render markdown to HTML (trimmed to match Self-Hosted behavior)
        let markdownParser = MarkdownParser()
        sidebarObject.contentHtml = markdownParser.html(from: content).trimmingCharacters(in: .whitespacesAndNewlines)

        // Update existing text block
        sidebarObject.title = title
        sidebarObject.content = content
    }
}

struct TextBlockFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blog: Blog
    var sidebarObject: SidebarObject?
    
    var body: some View {
        if let sidebarObject = sidebarObject {
            EditTextBlockView(sidebarObject: sidebarObject, blog: blog)
        } else {
            AddTextBlockView(blog: blog)
        }
    }
}
