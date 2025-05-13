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
    @State private var selectedTemplateName: String = ""
    @State private var editedContent: String = ""
    @State private var isEdited = false
    @State private var isLoading = true
    @State private var templateNames: [String] = []
    
    @State var theme: Theme
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading theme files...")
                            .foregroundStyle(.secondary)
                    }
                } else {
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
                            if templateNames.isEmpty {
                                Text("No template files found")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            } else {
                                ForEach(templateNames, id: \.self) { templateName in
                                    HStack {
                                        Text(templateName)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Button {
                                            selectedTemplateName = templateName
                                            if let content = theme.template(named: templateName) {
                                                editedContent = content
                                            } else {
                                                editedContent = "// No content found for this template"
                                            }
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
                            Text("Template Files (\(templateNames.count))")
                        }
                    }
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
                FileEditorView(
                    fileName: selectedTemplateName,
                    content: $editedContent,
                    onSave: {
                        theme.setTemplate(named: selectedTemplateName, content: editedContent)
                        isEdited = true
                    }
                )
            }
            .onAppear {
                // Load all templates from the theme
                print("ThemeEditor: Opening theme \(theme.identifier) - \(theme.name)")
                
                // Get all template keys
                templateNames = Array(theme.templates.keys).sorted()
                
                isLoading = false
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