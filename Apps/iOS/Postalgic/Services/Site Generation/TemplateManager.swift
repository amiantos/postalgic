//
//  TemplateManager.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import Mustache
import SwiftData

/// Manages and provides access to Mustache templates for the static site generator
class TemplateManager {
    // Default templates
    private var defaultTemplates = [String: String]()
    
    // Custom theme templates
    private var customTemplates = [String: String]()
    
    // Compiled templates
    private var compiledTemplates = [String: MustacheTemplate]()
    
    // Reference to the blog
    private let blog: Blog
    
    // The theme to use for templates
    private var theme: Theme?
    
    // MARK: - Initialization
    
    init(blog: Blog) {
        self.blog = blog
        setupDefaultTemplates()
        loadCustomTheme()
    }
    
    // MARK: - Template Setup

    /// Sets up the default templates by loading from bundled files
    private func setupDefaultTemplates() {
        // Map of template keys to their file names in the bundle
        let templateFiles: [(key: String, filename: String, ext: String?)] = [
            ("layout", "layout", "mustache"),
            ("post", "post", "mustache"),
            ("index", "index", "mustache"),
            ("archives", "archives", "mustache"),
            ("monthly-archive", "monthly-archive", "mustache"),
            ("tags", "tags", "mustache"),
            ("tag", "tag", "mustache"),
            ("categories", "categories", "mustache"),
            ("category", "category", "mustache"),
            ("css", "style", "css"),
            ("rss", "rss", "xml"),
            ("robots", "robots", "txt"),
            ("sitemap", "sitemap", "xml")
        ]

        // Try multiple possible subdirectory paths
        let possibleSubdirectories = [
            "Templates/default",
            "Resources/Templates/default",
            "default",
            nil  // No subdirectory - files at bundle root
        ]

        for (key, name, ext) in templateFiles {
            var loaded = false

            for subdirectory in possibleSubdirectories {
                if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
                   let content = try? String(contentsOf: url, encoding: .utf8) {
                    defaultTemplates[key] = content
                    loaded = true
                    break
                }
            }

            if !loaded {
                Log.warn("Could not load template file: \(name).\(ext ?? "") - searched in: \(possibleSubdirectories)")
            }
        }
    }

    // MARK: - Template Compilation
    
    // Create a library to store all templates for partials
    private lazy var templateLibrary: MustacheLibrary = {
        var library = MustacheLibrary()
        
        // First register default templates
        for (name, content) in defaultTemplates {
            do {
                try library.register(content, named: name)
            } catch {
                Log.error("Error registering default template \(name): \(error)")
            }
        }

        // Then register custom templates (overriding defaults if names match)
        for (name, content) in customTemplates {
            do {
                try library.register(content, named: name)
            } catch {
                Log.error("Error registering custom template \(name): \(error)")
            }
        }
        
        return library
    }()
    
    /// Compiles a template for the specified template type
    private func compileTemplate(for templateType: String) throws -> MustacheTemplate {
        // Check if we have a custom template for this type
        if let customTemplate = customTemplates[templateType] {
            return try MustacheTemplate(string: customTemplate)
        }
        // Fall back to the default template
        else if let defaultTemplate = defaultTemplates[templateType] {
            return try MustacheTemplate(string: defaultTemplate)
        } 
        // If no template exists for this type, throw an error
        else {
            throw TemplateError.templateNotFound(templateType)
        }
    }
    
    // MARK: - Template Access
    
    /// Loads the custom theme if one is specified in the blog's themeIdentifier
    private func loadCustomTheme() {
        guard let themeIdentifier = blog.themeIdentifier, themeIdentifier != "default" else {
            // Use default templates
            Log.debug("Using default theme")
            return
        }

        // Try to find the custom theme using the model context
        guard let modelContext = blog.modelContext else {
            Log.debug("No model context available for blog, using default theme")
            return
        }

        // Try to find the theme
        let descriptor = FetchDescriptor<Theme>()

        do {
            let allThemes = try modelContext.fetch(descriptor)

            // Find the theme with matching identifier
            if let customTheme = allThemes.first(where: { $0.identifier == themeIdentifier }) {
                Log.debug("Found theme: \(customTheme.name)")

                // Load all templates from the dictionary
                customTemplates = customTheme.templates

                Log.debug("Loaded \(customTemplates.count) templates from theme")
            } else {
                Log.debug("Theme with ID \(themeIdentifier) not found, using default theme")
            }
        } catch {
            Log.error("Error loading custom theme: \(error)")
        }
    }
    
    /// Gets the compiled template for the specified type
    /// - Parameter type: The type of template to retrieve
    /// - Returns: A compiled template
    /// - Throws: TemplateError if the template doesn't exist or can't be compiled
    func getTemplate(for type: String) throws -> MustacheTemplate {
        // Check if we already have a compiled template for this type
        if let template = compiledTemplates[type] {
            return template
        }
        
        do {
            // Otherwise compile and cache it
            let template = try compileTemplate(for: type)
            compiledTemplates[type] = template
            
            // Refresh the library when a template changes
            let _ = templateLibrary
            
            return template
        } catch {
            throw TemplateError.compilationFailed(type, error)
        }
    }
    
    /// Gets the template string content for the specified type
    /// - Parameter type: The type of template to retrieve
    /// - Returns: The template string
    /// - Throws: TemplateError if the template doesn't exist
    func getTemplateString(for type: String) throws -> String {
        // Check if we have a custom template for this type
        if let customTemplate = customTemplates[type] {
            return customTemplate
        }
        // Fall back to the default template
        else if let defaultTemplate = defaultTemplates[type] {
            return defaultTemplate
        } 
        // If no template exists for this type, throw an error
        else {
            throw TemplateError.templateNotFound(type)
        }
    }
    
    /// Returns all available template types
    /// - Returns: Array of template type identifiers
    func availableTemplateTypes() -> [String] {
        // Combine default and custom template types, with defaults taking precedence
        let allTemplateTypes = Set(defaultTemplates.keys)
        return Array(allTemplateTypes).sorted()
    }
    
    /// Returns the template library for use with partials
    /// - Returns: The template library
    func getLibrary() -> MustacheLibrary {
        return templateLibrary
    }
    
    // MARK: - Errors
    
    enum TemplateError: Error, LocalizedError {
        case templateNotFound(String)
        case compilationFailed(String, Error)
        
        var errorDescription: String? {
            switch self {
            case .templateNotFound(let type):
                return "Template not found: \(type)"
            case .compilationFailed(let type, let error):
                return "Failed to compile template \(type): \(error.localizedDescription)"
            }
        }
    }
}
