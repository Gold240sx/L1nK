//
//  SparkleTestApp.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import SwiftUI
import SwiftData
import Sparkle

@main
struct SparkleTestApp: App {
    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate: UpdaterDelegate
    private let updateChecker: UpdateChecker
    @Environment(\.scenePhase) private var scenePhase
    @State private var didRunLaunchCheck = false
    
    init() {
        // Create updater delegate for handling update events
        updaterDelegate = UpdaterDelegate()
        
        // Initialize updater controller with delegate
        // Set startingUpdater to false to avoid Sparkle's automatic checking
        // We'll handle checking manually through UpdateChecker to avoid duplicate checks
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        
        // Configure update checker
        // Customize these settings as needed:
        let updateConfig = UpdateChecker.Configuration(
            checkOnLaunch: true,           // Check on launch
            launchCheckDelay: 1.0,         // Wait 1 second after launch
            checkPeriodically: true,       // Check automatically every hour
            updateCheckInterval: 3600,     // 1 hour = 3600 seconds
            checkOnBecomeActive: false     // Don't check when app becomes active
        )
        
        // Create UpdateChecker - UpdateChecker.init defers accessing updater properties
        // so this should be safe even if updater isn't fully ready yet
        updateChecker = UpdateChecker(
            updater: updaterController.updater,
            configuration: updateConfig
        )
        
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !didRunLaunchCheck else { return }
            didRunLaunchCheck = true
            updateChecker.checkOnLaunch()
        }
    }
}

