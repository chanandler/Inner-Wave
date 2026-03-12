//
//  Inner_WaveApp.swift
//  Inner Wave
//
//  Created by Clint Yarwood on 19/10/2025.
//

import SwiftUI
import StoreKit

@main
struct Inner_WaveApp: App {
    @State private var settings = SettingsStore()
    @State private var rhythm = BreathingRhythm()
    @State private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(rhythm)
                .environment(sessionStore)
                // Finish any transactions that completed while the app was inactive
                .task {
                    for await result in Transaction.updates {
                        if case .verified(let transaction) = result {
                            await transaction.finish()
                        }
                    }
                }
        }
    }
}
