import Foundation
import Sparkle

/// Delegate to handle automatic update checking on app launch
/// Note: SPUUpdaterDelegate protocol methods are optional in Sparkle 2.
/// This delegate can be extended with optional methods as needed.
class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    /// Called when update check finds an update
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Notify that update is available
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateAvailable"),
            object: nil,
            userInfo: ["item": item]
        )
    }
    
    /// Called when no update is found
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NoUpdateAvailable"),
            object: nil
        )
    }
    
    /// Called when update check fails with an error
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let errorMessage = error.localizedDescription.lowercased()
        
        // Check if this is actually a "no update available" message
        // Some Sparkle versions report "up to date" as an error
        if errorMessage.contains("up to date") || 
           errorMessage.contains("latest version") ||
           errorMessage.contains("no update") {
            NotificationCenter.default.post(
                name: NSNotification.Name("NoUpdateAvailable"),
                object: nil
            )
        } else {
            print("Sparkle update check failed: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdateCheckError"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }
}
