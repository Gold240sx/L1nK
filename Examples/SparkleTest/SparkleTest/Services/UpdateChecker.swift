//
//  UpdateChecker.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import Foundation
import Sparkle

/// Manages automatic update checking behavior
class UpdateChecker {
    private let updater: SPUUpdater
    
    /// Configuration for update checking behavior
    struct Configuration {
        /// Check for updates on app launch (default: true)
        var checkOnLaunch: Bool = true
        
        /// Delay before checking on launch in seconds (default: 1.0)
        var launchCheckDelay: TimeInterval = 1.0
        
        /// Automatically check periodically (default: true)
        var checkPeriodically: Bool = true
        
        /// Interval between automatic checks in seconds (default: 3600 = 1 hour)
        var updateCheckInterval: TimeInterval = 3600
        
        /// Check when app becomes active (default: false)
        var checkOnBecomeActive: Bool = false
    }
    
    private let configuration: Configuration
    
    init(updater: SPUUpdater, configuration: Configuration = Configuration()) {
        self.updater = updater
        self.configuration = configuration
        
        // Defer setup to avoid accessing updater during initialization
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.startUpdater()
            self.setupAutomaticChecking()
        }
    }
    
    /// Starts the updater - must be called before checkForUpdates
    private func startUpdater() {
        do {
            try updater.start()
        } catch {
            print("Failed to start Sparkle updater: \(error)")
        }
    }
    
    /// Sets up automatic update checking based on configuration
    private func setupAutomaticChecking() {
        if configuration.checkPeriodically {
            updater.updateCheckInterval = configuration.updateCheckInterval
        }
    }
    
    /// Checks for updates on app launch
    func checkOnLaunch() {
        guard configuration.checkOnLaunch else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.launchCheckDelay) {
            self.updater.checkForUpdates()
        }
    }
    
    /// Checks for updates when app becomes active
    func checkOnBecomeActive() {
        guard configuration.checkOnBecomeActive else { return }
        updater.checkForUpdates()
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

