//
//  ThemeService.swift
//  Postalgic
//
//  Created by Brad Root on 5/13/25.
//

import Foundation
import SwiftData

/// A singleton service to manage themes across the app
class ThemeService {
    // Singleton instance
    static let shared = ThemeService()
    
    // In-memory repository of themes
    private var themeCache: [String: Theme] = [:]
    
    // Private initializer for singleton
    private init() {}
    
    /// Add a theme to the cache
    func addTheme(_ theme: Theme) {
        themeCache[theme.identifier] = theme
        print("ThemeService: Added theme \(theme.identifier) to cache")
    }
    
    /// Get a theme by identifier
    func getTheme(identifier: String) -> Theme? {
        return themeCache[identifier]
    }
    
    /// Get all cached themes
    func getAllThemes() -> [Theme] {
        return Array(themeCache.values)
    }
    
    /// Create a duplicate of the default theme
    func duplicateDefaultTheme(modelContext: ModelContext, templateManager: TemplateManager) -> Theme {
        // Create a unique ID for the theme
        let uniqueId = "custom_\(UUID().uuidString)"
        
        // Create the theme
        let customTheme = Theme(
            name: "Default (Customized)",
            identifier: uniqueId,
            isCustomized: true
        )
        
        // Add it to the model context
        modelContext.insert(customTheme)
        
        // Add the template files from the default theme
        for templateType in templateManager.availableTemplateTypes() {
            do {
                let content = try templateManager.getTemplateString(for: templateType)
                let file = ThemeFile(
                    theme: customTheme,
                    name: templateType,
                    content: content
                )
                
                modelContext.insert(file)
                customTheme.files.append(file)
            } catch {
                print("Error creating template file: \(error)")
            }
        }
        
        // Save to database
        try? modelContext.save()
        
        // Add to our cache
        addTheme(customTheme)
        
        return customTheme
    }
    
    /// Load themes from the database into the cache
    func loadThemesFromDatabase(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Theme>()
        do {
            let themes = try modelContext.fetch(descriptor)
            print("ThemeService: Loaded \(themes.count) themes from database")
            
            // Add each to the cache
            for theme in themes {
                addTheme(theme)
                print("ThemeService: Cached theme \(theme.identifier) with \(theme.files.count) files")
            }
        } catch {
            print("ThemeService: Error loading themes from database - \(error)")
        }
    }
    
    /// Get template content for a specific theme
    func getTemplateContent(themeId: String, templateName: String) -> String? {
        guard let theme = themeCache[themeId] else {
            print("ThemeService: Theme \(themeId) not found in cache")
            return nil
        }
        
        guard let file = theme.files.first(where: { $0.name == templateName }) else {
            print("ThemeService: Template \(templateName) not found in theme \(themeId)")
            return nil
        }
        
        return file.content
    }
}