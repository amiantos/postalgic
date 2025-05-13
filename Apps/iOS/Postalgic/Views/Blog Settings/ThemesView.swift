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
    
    @Query private var allThemes: [Theme]
    
    var blog: Blog
    
    private var sortedThemes: [Theme] {
        // Now we only sort the customized themes since default is not stored in database
        allThemes.sorted { $0.name < $1.name }
    }
    
    @State private var showingThemeEditor = false
    @State private var selectedTheme: Theme?
    
    init(blog: Blog) {
        self.blog = blog
        self._allThemes = Query()
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
                if !sortedThemes.isEmpty {
                    Section("Custom Themes") {
                        ForEach(sortedThemes) { theme in
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
                ensureDefaultThemeExists()
            }
        }
    }
    
    private func ensureDefaultThemeExists() {
        // We don't need to create a default theme in the database anymore
        // since the default theme templates are hardcoded in TemplateManager
        
        // Make sure the blog has a themeIdentifier set
        if blog.themeIdentifier == nil {
            blog.themeIdentifier = "default"
        }
    }
    
    private func duplicateDefaultTheme() {
        // Create a template manager to access default templates
        let templateManager = TemplateManager(blog: blog)
        
        // Create a new customized theme
        let customizedTheme = Theme(
            name: "Default (Customized)",
            identifier: "default_customized_\(UUID().uuidString)",
            isCustomized: true
        )
        
        // Copy all templates from the default theme in TemplateManager
        for templateType in templateManager.availableTemplateTypes() {
            do {
                let templateContent = try templateManager.getTemplateString(for: templateType)
                let themeFile = ThemeFile(
                    theme: customizedTheme,
                    name: templateType,
                    content: templateContent
                )
                customizedTheme.files.append(themeFile)
            } catch {
                print("Error creating theme file for \(templateType): \(error)")
            }
        }
        
        modelContext.insert(customizedTheme)
        
        // Automatically select the new theme
        blog.themeIdentifier = customizedTheme.identifier
        
        // Show the theme editor for the new theme
        selectedTheme = customizedTheme
        showingThemeEditor = true
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
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return ThemesView(blog: blog)
        .modelContainer(modelContainer)
}
