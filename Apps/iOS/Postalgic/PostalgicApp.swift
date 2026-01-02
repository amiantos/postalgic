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
    init() {
        #if DEBUG
        Log.logLevel = .debug
        #else
        Log.logLevel = .error
        #endif
    }

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
}
