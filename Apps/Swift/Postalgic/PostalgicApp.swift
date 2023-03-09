//
//  PostalgicApp.swift
//  Postalgic
//
//  Created by Brad Root on 3/9/23.
//

import SwiftUI

@main
struct PostalgicApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
