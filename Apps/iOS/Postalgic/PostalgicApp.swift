//
//  PostalgicApp.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI

@main
struct PostalgicApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Blog.self,
            Post.self,
            Tag.self,
            Category.self,
            Theme.self,
        ])

        // Check if we're running UI tests and need to reset data
        let isUITesting = ProcessInfo.processInfo.arguments.contains(
            "-UITesting"
        )
        let shouldResetData = ProcessInfo.processInfo.arguments.contains(
            "-DataReset"
        )

        // Configure migration options to safely handle schema changes
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Clear all data if requested
            if isUITesting && shouldResetData {
                try container.mainContext.delete(model: Blog.self)
                try container.mainContext.delete(model: Post.self)
                try container.mainContext.delete(model: Tag.self)
                try container.mainContext.delete(model: Category.self)
                try container.mainContext.delete(model: Theme.self)
            }
            
            // Initialize the theme service
            ThemeService.shared.loadThemesFromDatabase(modelContext: container.mainContext)
            
            // Migrate passwords to keychain for all blogs
            if !isUITesting {
                Task {
                    await Self.migrateAllBlogsPasswordsToKeychain(context: container.mainContext)
                }
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            BlogsView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Migrates all blogs' passwords from SwiftData to Keychain
    private static func migrateAllBlogsPasswordsToKeychain(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<Blog>()
            let blogs = try context.fetch(descriptor)
            
            // For each blog, attempt to migrate passwords to keychain
            for blog in blogs {
                blog.migratePasswordsToKeychain()
            }
            
            // Save changes to SwiftData
            try context.save()
            print("Successfully migrated all blog passwords to keychain")
        } catch {
            print("Error migrating passwords to keychain: \(error)")
        }
    }
}
