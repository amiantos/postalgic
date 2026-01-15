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
        Log.debug("ThemeService: Added theme \(theme.identifier) to cache")
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
    func duplicateDefaultTheme(modelContext: ModelContext, templates: [String: String]) -> Theme {
        // Create a unique ID for the theme
        let uniqueId = "custom_\(UUID().uuidString)"
        
        // Create the theme
        let customTheme = Theme(
            name: "Default (Customized)",
            identifier: uniqueId,
            isCustomized: true
        )
        
        // Add all templates to the theme
        for (templateName, content) in templates {
            customTheme.setTemplate(named: templateName, content: content)
        }
        
        // Add it to the model context
        modelContext.insert(customTheme)
        
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
            Log.debug("ThemeService: Loaded \(themes.count) themes from database")

            // Add each to the cache
            for theme in themes {
                addTheme(theme)
                Log.verbose("ThemeService: Cached theme \(theme.identifier) with \(theme.templates.count) templates")
            }
        } catch {
            Log.error("ThemeService: Error loading themes from database - \(error)")
        }
    }

    /// Get template content for a specific theme
    func getTemplateContent(themeId: String, templateName: String) -> String? {
        guard let theme = themeCache[themeId] else {
            Log.debug("ThemeService: Theme \(themeId) not found in cache")
            return nil
        }

        return theme.template(named: templateName)
    }
}