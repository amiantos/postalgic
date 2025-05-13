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
    
    // Using ThemeService to manage themes
    @State private var themes: [Theme] = []
    
    var blog: Blog
    
    @State private var showingThemeEditor = false
    @State private var selectedTheme: Theme?
    
    // Reference to ThemeService
    private let themeService = ThemeService.shared
    
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
        
        // Load themes from the service
        themeService.loadThemesFromDatabase(modelContext: modelContext)
        
        // Get themes from the service
        themes = themeService.getAllThemes()
        
        print("Loaded \(themes.count) themes from ThemeService")
    }
    
    private func duplicateDefaultTheme() {
        // Use the theme service to create the duplicate
        let templateManager = TemplateManager(blog: blog)
        let newTheme = themeService.duplicateDefaultTheme(
            modelContext: modelContext,
            templateManager: templateManager
        )
        
        // Update the blog to use the new theme
        blog.themeIdentifier = newTheme.identifier
        try? modelContext.save()
        
        // Refresh our local list
        loadThemes()
        
        // Show the theme editor
        selectedTheme = newTheme
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
