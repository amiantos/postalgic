//
//  PostalgicApp.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

@main
struct PostalgicApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Blog.self,
            Post.self,
            Tag.self,
            Category.self
        ])
        
        // Check if we're running UI tests and need to reset data
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let shouldResetData = ProcessInfo.processInfo.arguments.contains("-DataReset")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Clear all data if requested
            if isUITesting && shouldResetData {
                try container.mainContext.delete(model: Blog.self)
                try container.mainContext.delete(model: Post.self)
                try container.mainContext.delete(model: Tag.self)
                try container.mainContext.delete(model: Category.self)
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
}