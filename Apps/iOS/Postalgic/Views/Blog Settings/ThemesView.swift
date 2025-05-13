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
    
    // Manually track themes to avoid SwiftData refresh issues
    @State private var themes: [Theme] = []
    
    var blog: Blog
    
    @State private var showingThemeEditor = false
    @State private var selectedTheme: Theme?
    
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
                                selectTheme(theme)
                            }
                            .swipeActions(edge: .trailing) {
                                if theme.isCustomized {
                                    Button {
                                        showThemeEditor(theme)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                    
                                    Button(role: .destructive) {
                                        deleteTheme(theme)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    duplicateDefaultTheme()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Duplicate Default Theme")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Themes")
            .sheet(isPresented: $showingThemeEditor, content: {
                if let theme = selectedTheme {
                    ThemeEditorView(theme: theme)
                }
            })
            .onAppear {
                loadThemes()
            }
        }
    }
    
    private func loadThemes() {
        // Make sure blog has a themeIdentifier set
        if blog.themeIdentifier == nil {
            blog.themeIdentifier = "default"
        }
        
        // Load all themes from the database
        let descriptor = FetchDescriptor<Theme>()
        do {
            themes = try modelContext.fetch(descriptor)
            print("Loaded \(themes.count) themes")
        } catch {
            print("Error loading themes: \(error)")
        }
    }
    
    private func duplicateDefaultTheme() {
        // Generate a unique identifier
        let uniqueId = "custom_\(UUID().uuidString)"
        print("Creating new theme with ID: \(uniqueId)")
        
        // Create a new theme with a simple structure
        let newTheme = Theme(
            name: "Default (Customized)",
            identifier: uniqueId,
            isCustomized: true
        )
        
        // Insert the theme first
        modelContext.insert(newTheme)
        
        // Add template files from the default theme
        let templateManager = TemplateManager(blog: blog)
        for templateType in templateManager.availableTemplateTypes() {
            do {
                let content = try templateManager.getTemplateString(for: templateType)
                let file = ThemeFile(
                    theme: newTheme,
                    name: templateType,
                    content: content
                )
                
                // Insert each file into the model context
                modelContext.insert(file)
                
                // Also add it to the theme's relationship
                newTheme.files.append(file)
                
                print("Added template file: \(templateType)")
            } catch {
                print("Error getting template \(templateType): \(error)")
            }
        }
        
        // Save everything
        do {
            try modelContext.save()
            print("Successfully saved theme with \(newTheme.files.count) files")
            
            // Update our local list
            themes.append(newTheme)
            
            // Select the new theme
            blog.themeIdentifier = uniqueId
            
            // Save blog changes
            try modelContext.save()
            
            print("Successfully set blog theme to: \(uniqueId)")
        } catch {
            print("Error saving theme: \(error)")
        }
    }
    
    private func selectTheme(_ theme: Theme) {
        blog.themeIdentifier = theme.identifier
    }
    
    private func showThemeEditor(_ theme: Theme) {
        selectedTheme = theme
        showingThemeEditor = true
    }
    
    private func deleteTheme(_ theme: Theme) {
        // If this is the currently selected theme, revert to default
        if blog.themeIdentifier == theme.identifier {
            blog.themeIdentifier = "default"
        }
        
        // Delete the theme
        modelContext.delete(theme)
        
        // Update our local list
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes.remove(at: index)
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return ThemesView(blog: blog)
        .modelContainer(modelContainer)
}
