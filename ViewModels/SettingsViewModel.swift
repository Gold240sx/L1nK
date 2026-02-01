import SwiftUI
import Foundation
import ServiceManagement
import Sparkle

class SettingsViewModel: ObservableObject {
    @AppStorage("defaultSaveDirectory") var defaultSaveDirectory: String = ""
    @AppStorage("askToSave") var askToSave: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("useCustomYouTubeApp") var useCustomYouTubeApp: Bool = false
    @AppStorage("customYouTubeAppPath") var customYouTubeAppPath: String = ""
    
    @Published var message: String = ""
    @Published var showPermissionAlert: Bool = false
    @Published var lastError: String = ""
    
    @Published var updateStatus: UpdateStatus = .idle
    @Published var isCheckingForUpdates: Bool = false
    @Published var hasUpdateAvailable: Bool = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case updateAvailable
        case noUpdateAvailable
        case error(String)
        
        static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.updateAvailable, .updateAvailable), (.noUpdateAvailable, .noUpdateAvailable):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    private var updateChecker: UpdateChecker?
    private var updater: SPUUpdater?
    
    func setUpdateChecker(_ checker: UpdateChecker?) {
        self.updateChecker = checker
    }
    
    func setUpdater(_ updater: SPUUpdater?) {
        self.updater = updater
        checkForUpdateAvailability()
    }
    
    private func checkForUpdateAvailability() {
        // Check if updater has found an update
        // Note: Sparkle doesn't expose a direct property for this, so we'll track it via delegate callbacks
        // For now, we'll check periodically or when settings view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This is a placeholder - we'll update this when update is found via delegate
        }
    }
    
    func setUpdateAvailable(_ available: Bool) {
        hasUpdateAvailable = available
    }
    
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateStatus = .checking
        
        // Set callback in delegate to receive status updates
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let updaterDelegate = appDelegate.updaterDelegate {
            updaterDelegate.setUpdateStatusCallback { [weak self] status in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isCheckingForUpdates = false
                    switch status {
                    case .checking:
                        self.updateStatus = .checking
                    case .updateAvailable:
                        self.updateStatus = .updateAvailable
                        self.hasUpdateAvailable = true
                    case .noUpdateAvailable:
                        self.updateStatus = .noUpdateAvailable
                        // Clear message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if self.updateStatus == .noUpdateAvailable {
                                self.updateStatus = .idle
                            }
                        }
                    case .error(let errorMessage):
                        self.updateStatus = .error(errorMessage)
                        // Clear error after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            if case .error = self.updateStatus {
                                self.updateStatus = .idle
                            }
                        }
                    }
                }
            }
        }
        
        updateChecker?.checkForUpdates()
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                message = enabled ? "Launch at login enabled" : "Launch at login disabled"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.message = ""
                }
            } catch {
                print("Failed to toggle login item: \(error)")
                message = "Failed to update login setting."
            }
        } else {
            message = "Launch at login requires macOS 13+"
        }
    }
    
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.begin { [weak self] response in
            if response == .OK {
                self?.defaultSaveDirectory = panel.url?.path ?? ""
            }
        }
    }
    
    func selectYouTubeApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.customYouTubeAppPath = url.path
            }
        }
    }
}
