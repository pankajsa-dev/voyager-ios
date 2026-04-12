//
//  VoyagerApp.swift
//  Voyager
//
//  Created by Pankaj Sachdeva on 12.04.26.
//

import SwiftUI
import SwiftData

@main
struct VoyagerApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Destination.self,
            Trip.self,
            Booking.self,
            Expense.self,
            PackingItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
