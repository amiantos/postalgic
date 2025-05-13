//
//  ThemesView.swift
//  Postalgic
//
//  Created by Brad Root on 5/13/25.
//

import SwiftUI
import SwiftData

struct ThemesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Use Query to directly fetch all themes
    @Query private var themes: [Theme]
    
    var blog: Blog

    @State private var selectedTheme: Theme? = nil
    
    init(blog: Blog) {
        self.blog = blog
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Default theme row (always shown first)
                HStack {
                    VStack(alignment: .leading) {
                        Text("Default")
                            .font(.headline)
                            
                        Text("Built-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if blog.themeIdentifier == "default" || blog.themeIdentifier == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    blog.themeIdentifier = "default"
                    try? modelContext.save()
                }
                
                // Section for custom themes
                if !themes.isEmpty {
                    Section("Custom Themes") {
                        ForEach(themes) { theme in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(theme.name)
                                        .font(.headline)
                                    
                                    if theme.isCustomized {
                                        Text("Customized")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if blog.themeIdentifier == theme.identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                blog.themeIdentifier = theme.identifier
                                try? modelContext.save()
                            }
                            .swipeActions(edge: .trailing) {
                                if theme.isCustomized {
                                    Button {
                                        selectedTheme = theme
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                    
                                    Button(role: .destructive) {
                                        if blog.themeIdentifier == theme.identifier {
                                            blog.themeIdentifier = "default"
                                        }
                                        modelContext.delete(theme)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        duplicateDefaultTheme()
                    } label: {
                        Label("New Theme", systemImage: "plus")
                    }
                }
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Themes")
            .sheet(item: $selectedTheme) { theme in
                ThemeEditorView(theme: theme)
            }
        }
    }
    
    private func duplicateDefaultTheme() {
        // Create a new theme
        let customTheme = Theme(
            name: "Default (Customized)", 
            identifier: "custom_\(UUID().uuidString)",
            isCustomized: true
        )
        
        // Copy default templates from TemplateManager
        let templateManager = TemplateManager(blog: blog)
        for templateType in templateManager.availableTemplateTypes() {
            do {
                let content = try templateManager.getTemplateString(for: templateType)
                customTheme.setTemplate(named: templateType, content: content)
            } catch {
                print("Error copying template: \(error)")
            }
        }
        
        // Save the new theme
        modelContext.insert(customTheme)
        try? modelContext.save()
        
        // Set it as the active theme
        blog.themeIdentifier = customTheme.identifier
        try? modelContext.save()
        
        // Show the editor
        selectedTheme = customTheme
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return ThemesView(blog: blog)
        .modelContainer(modelContainer)
}
