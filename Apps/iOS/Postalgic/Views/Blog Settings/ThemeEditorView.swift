//
//  ThemeEditorView.swift
//  Postalgic
//
//  Created by Brad Root on 5/13/25.
//

import SwiftUI
import SwiftData

struct ThemeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFileEditor = false
    @State private var selectedFile: ThemeFile?
    @State private var editedContent: String = ""
    @State private var isEdited = false
    
    @State var theme: Theme
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Theme Name", text: $theme.name)
                        .onChange(of: theme.name) {
                            isEdited = true
                        }
                } header: {
                    Text("Theme Settings")
                }
                
                Section {
                    if theme.files.isEmpty {
                        Text("No template files found")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(theme.files) { file in
                            HStack {
                                Text(file.name)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button {
                                    selectedFile = file
                                    editedContent = file.content
                                    showingFileEditor = true
                                } label: {
                                    HStack {
                                        Text("Edit")
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Template Files")
                }
            }
            .navigationTitle("Edit Theme")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if isEdited {
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFileEditor) {
                if let file = selectedFile {
                    FileEditorView(
                        fileName: file.name,
                        content: $editedContent,
                        onSave: {
                            file.content = editedContent
                            file.lastModified = Date()
                            isEdited = true
                        }
                    )
                }
            }
            .onAppear {
                // Refresh the list of files when the view appears
                if theme.files.isEmpty {
                    print("Theme has no files, this might be a problem")
                } else {
                    print("Theme has \(theme.files.count) files")
                }
            }
        }
    }
}

// This view handles editing an individual template file
struct FileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let fileName: String
    @Binding var content: String
    let onSave: () -> Void
    
    @State private var tempContent: String = ""
    @State private var showingDiscardAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $tempContent)
                    .font(.system(size: 14, design: .monospaced))
                    .padding()
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if tempContent != content {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        content = tempContent
                        onSave()
                        dismiss()
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .onAppear {
                tempContent = content
            }
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    // Fetch a theme or create one if it doesn't exist
    let theme: Theme
    let themes = try? modelContainer.mainContext.fetch(FetchDescriptor<Theme>())
    
    if let existingTheme = themes?.first {
        theme = existingTheme
    } else {
        theme = Theme(name: "Preview Theme", identifier: "preview")
        let file = ThemeFile(theme: theme, name: "css", content: "/* CSS content */")
        theme.files.append(file)
        modelContainer.mainContext.insert(theme)
        try? modelContainer.mainContext.save()
    }
    
    return ThemeEditorView(theme: theme)
        .modelContainer(modelContainer)
}
