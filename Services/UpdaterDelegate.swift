import Foundation
import Sparkle

/// Delegate to handle automatic update checking on app launch
/// Note: SPUUpdaterDelegate protocol methods are optional in Sparkle 2.
/// This delegate can be extended with optional methods as needed.
class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private var isManualCheck: Bool = false
    private var updateStatusCallback: ((UpdateStatus) -> Void)?
    
    enum UpdateStatus {
        case checking
        case updateAvailable
        case noUpdateAvailable
        case error(String)
    }
    
    /// Set whether this is a manual check (user-initiated)
    func setManualCheck(_ manual: Bool) {
        isManualCheck = manual
    }
    
    /// Set callback for update status changes
    func setUpdateStatusCallback(_ callback: @escaping (UpdateStatus) -> Void) {
        updateStatusCallback = callback
    }
    
    /// Called when update check starts
    func updaterDidStartUpdateCheck(_ updater: SPUUpdater) {
        if isManualCheck {
            updateStatusCallback?(.checking)
        }
    }
    
    /// Called when update check finds an update
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Always notify that update is available (for both manual and automatic checks)
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateAvailable"),
            object: nil,
            userInfo: ["item": item]
        )
        
        if isManualCheck {
            updateStatusCallback?(.updateAvailable)
        }
        // For automatic checks, Sparkle will show its own UI, but we still track it
    }
    
    /// Called when update check doesn't find an update
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        if isManualCheck {
            updateStatusCallback?(.noUpdateAvailable)
        }
        // For automatic checks, don't show anything
    }
    
    /// Called when update check encounters an error
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if isManualCheck {
            updateStatusCallback?(.error(error.localizedDescription))
        }
    }
}
