import SwiftUI
import SwiftData
import AppKit
import Sparkle

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// Shared holder for Sparkle updater components
class SparkleManager {
    static let shared = SparkleManager()
    
    let updaterController: SPUStandardUpdaterController
    let updaterDelegate: UpdaterDelegate
    
    private init() {
        // Create updater delegate for handling update events
        let delegate = UpdaterDelegate()
        
        // Initialize updater controller with delegate
        // Set startingUpdater to true to let Sparkle handle automatic updates
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        
        self.updaterDelegate = delegate
        self.updaterController = controller
    }
    
    /// Check for updates manually (user-initiated)
    func checkForUpdates() {
        let updater = updaterController.updater
        // Only check if not already checking
        if updater.canCheckForUpdates {
            updater.checkForUpdates()
        }
    }
}

@main
struct L1nkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize SparkleManager (triggers singleton creation)
        _ = SparkleManager.shared
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: SparkleManager.shared.updaterController.updater)
            }
        }
    }
}

class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class WelcomeWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class AuthWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    /// Static flag to ensure status item is only created once across all instances
    private static var statusItemCreated = false
    
    var statusItem: NSStatusItem?
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var authWindow: NSWindow?
    var subscriptionWindow: NSWindow?
    var eventMonitor: EventMonitor?
    var focusTimer: Timer?
    
    /// SwiftData model container for persistent tabs
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent duplicate status item creation using static flag
        guard !AppDelegate.statusItemCreated else { return }
        AppDelegate.statusItemCreated = true
        // Initialize SwiftData ModelContainer
        // Try CloudKit first, fall back to local-only if CloudKit isn't configured
        do {
            let schema = Schema([PersistentTab.self, TabFolder.self])
            
            // Try with CloudKit enabled
            let cloudKitConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [cloudKitConfig])
                print("ModelContainer created with CloudKit sync enabled")
            } catch {
                // CloudKit failed, fall back to local-only storage
                print("CloudKit not available, using local storage: \(error.localizedDescription)")
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("ModelContainer created with local storage only")
            }
            
            // Configure TabManager with the model context
            if let context = modelContainer?.mainContext {
                TabManager.shared.configure(with: context)
            }
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
        // Service
        NSApp.servicesProvider = self
        
        // Sparkle handles automatic update checking via startingUpdater: true
        // Clerk is configured and loaded via .task modifier in ContentView
        
        // Show welcome window on first launch
        checkAndShowWelcome()
        
        // Setup Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "L1nk")
            button.action = #selector(togglePopover(_:))
        }
        
        // Setup Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 460)
        popover.behavior = .transient
        popover.animates = true
        // Using ContentView as the root view for the popover
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        // Set delegate to handle dismissal
        popover.delegate = self
        
        // Listen for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: NSNotification.Name("ClosePopover"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsWindow),
            name: NSNotification.Name("ShowSettings"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeSettingsWindow),
            name: NSNotification.Name("CloseSettingsWindow"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reactivatePopover),
            name: NSNotification.Name("ReactivatePopover"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeWelcomeWindow),
            name: NSNotification.Name("CloseWelcomeWindow"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showWelcomeWindow),
            name: NSNotification.Name("ShowWelcomeWindow"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateAvailable),
            name: NSNotification.Name("UpdateAvailable"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showAuthWindow),
            name: NSNotification.Name("ShowAuthWindow"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeAuthWindow),
            name: NSNotification.Name("CloseAuthWindow"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSubscriptionWindow),
            name: NSNotification.Name("ShowSubscriptionView"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeSubscriptionWindow),
            name: NSNotification.Name("CloseSubscriptionWindow"),
            object: nil
        )
        
        // Monitor for app activation to keep popover focused
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    @objc func reactivatePopover() {
        // Ensure popover regains focus after save panel closes
        guard popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        keepPopoverFocused()
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        // Keep popover focused when app becomes active, but don't reopen if closed
        if popover.isShown {
            keepPopoverFocused()
        }
    }
    
    @objc func showSettingsWindow() {
        // Close popover first
        closePopover()
        
        // Create window if it doesn't exist
        if settingsWindow == nil {
            let contentView = SettingsView()
            let hostingView = NSHostingController(rootView: contentView)
            
            settingsWindow = SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 550),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.collectionBehavior = [.moveToActiveSpace]
            
            // Create visual effect view for glass background
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.frame = NSRect(x: 0, y: 0, width: 400, height: 550)
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 16
            visualEffectView.layer?.masksToBounds = true
            
            // Add hosting view as subview
            hostingView.view.frame = visualEffectView.bounds
            hostingView.view.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(hostingView.view)
            
            settingsWindow?.contentView = visualEffectView
            settingsWindow?.hasShadow = true
            settingsWindow?.isMovableByWindowBackground = true
            settingsWindow?.level = .floating
            settingsWindow?.isOpaque = false
            settingsWindow?.backgroundColor = .clear
            settingsWindow?.isMovable = true
        }
        
        // Show and activate the window
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func closeSettingsWindow() {
        settingsWindow?.close()
    }
    
    @objc func checkAndShowWelcome() {
        // Check if user has seen welcome screen
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        
        if !hasSeenWelcome {
            // Show welcome window after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeWindow()
            }
        }
    }
    
    @objc func showWelcomeWindow() {
        // Create window if it doesn't exist
        if welcomeWindow == nil {
            let contentView = WelcomeView(isPresented: Binding(
                get: { true },
                set: { _ in }
            ))
            let hostingView = NSHostingController(rootView: contentView)
            
            welcomeWindow = WelcomeWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            welcomeWindow?.center()
            welcomeWindow?.isReleasedWhenClosed = false
            welcomeWindow?.collectionBehavior = [.moveToActiveSpace]
            
            // Create visual effect view for glass background
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 20
            visualEffectView.layer?.masksToBounds = true
            
            // Add hosting view as subview
            hostingView.view.frame = visualEffectView.bounds
            hostingView.view.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(hostingView.view)
            
            welcomeWindow?.contentView = visualEffectView
            welcomeWindow?.hasShadow = true
            welcomeWindow?.isMovableByWindowBackground = true
            welcomeWindow?.level = .floating
            welcomeWindow?.isOpaque = false
            welcomeWindow?.backgroundColor = .clear
            welcomeWindow?.isMovable = true
        }
        
        // Show and activate the window
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func closeWelcomeWindow() {
        welcomeWindow?.close()
        welcomeWindow = nil
    }
    
    @objc func showAuthWindow() {
        // Close popover first
        closePopover()
        
        // Create window if it doesn't exist
        if authWindow == nil {
            let contentView = SignInView()
            let hostingView = NSHostingController(rootView: contentView)
            
            authWindow = AuthWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            authWindow?.center()
            authWindow?.isReleasedWhenClosed = false
            authWindow?.collectionBehavior = [.moveToActiveSpace]
            
            // Create visual effect view for glass background
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.frame = NSRect(x: 0, y: 0, width: 420, height: 520)
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 16
            visualEffectView.layer?.masksToBounds = true
            
            // Add hosting view as subview
            hostingView.view.frame = visualEffectView.bounds
            hostingView.view.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(hostingView.view)
            
            authWindow?.contentView = visualEffectView
            authWindow?.hasShadow = true
            authWindow?.isMovableByWindowBackground = true
            authWindow?.level = .floating
            authWindow?.isOpaque = false
            authWindow?.backgroundColor = .clear
            authWindow?.isMovable = true
        }
        
        // Show and activate the window
        authWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func closeAuthWindow() {
        authWindow?.close()
        authWindow = nil
    }
    
    @objc func showSubscriptionWindow() {
        // Close popover first
        closePopover()
        
        // Create window if it doesn't exist
        if subscriptionWindow == nil {
            let contentView = SubscriptionView()
            let hostingView = NSHostingController(rootView: contentView)
            
            subscriptionWindow = AuthWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 580),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            subscriptionWindow?.center()
            subscriptionWindow?.isReleasedWhenClosed = false
            subscriptionWindow?.collectionBehavior = [.moveToActiveSpace]
            
            // Create visual effect view for glass background
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.frame = NSRect(x: 0, y: 0, width: 380, height: 580)
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 16
            visualEffectView.layer?.masksToBounds = true
            
            // Add hosting view as subview
            hostingView.view.frame = visualEffectView.bounds
            hostingView.view.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(hostingView.view)
            
            subscriptionWindow?.contentView = visualEffectView
            subscriptionWindow?.hasShadow = true
            subscriptionWindow?.isMovableByWindowBackground = true
            subscriptionWindow?.level = .floating
            subscriptionWindow?.isOpaque = false
            subscriptionWindow?.backgroundColor = .clear
            subscriptionWindow?.isMovable = true
        }
        
        // Show and activate the window
        subscriptionWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func closeSubscriptionWindow() {
        subscriptionWindow?.close()
        subscriptionWindow = nil
    }
    
    @objc func handleUpdateAvailable(_ notification: Notification) {
        // This notification is handled by SettingsView via onReceive
        // We can add additional logic here if needed
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
            eventMonitor?.stop()
            stopFocusTimer()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            // Ensure popover window is key to keep it tinted
            DispatchQueue.main.async {
                self.keepPopoverFocused()
                self.startFocusTimer()
            }
            startEventMonitor()
        }
    }
    
    func keepPopoverFocused() {
        // Only keep focused if popover is actually shown
        guard popover.isShown else { return }
        
        // Access the popover's window and keep it key (popovers can't be main windows)
        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.makeKey()
            // Ensure the app is active to keep popover tinted
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func startFocusTimer() {
        // Periodically ensure popover stays focused
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.popover.isShown else {
                self?.focusTimer?.invalidate()
                return
            }
            self.keepPopoverFocused()
        }
    }
    
    func stopFocusTimer() {
        focusTimer?.invalidate()
        focusTimer = nil
    }
    
    func startEventMonitor() {
        // Stop any existing monitor first
        eventMonitor?.stop()
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else {
                return
            }
            
            // Check if click is outside popover
            if let popoverWindow = self.popover.contentViewController?.view.window {
                let windowLocation = popoverWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                
                if !popoverWindow.frame.contains(windowLocation) {
                    // Click is outside popover, close it
                    self.popover.performClose(nil)
                    self.eventMonitor?.stop()
                    self.stopFocusTimer()
                } else {
                    // Click is inside, keep focused
                    self.keepPopoverFocused()
                }
            } else {
                // Popover window not found, close anyway
                self.popover.performClose(nil)
                self.eventMonitor?.stop()
                self.stopFocusTimer()
            }
        }
        eventMonitor?.start()
    }
    
    // MARK: - NSPopoverDelegate
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return true
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Popover closed, stop monitoring events and focus timer
        eventMonitor?.stop()
        stopFocusTimer()
    }
    
    func popoverWillShow(_ notification: Notification) {
        // Ensure app is active when popover shows
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func popoverDidShow(_ notification: Notification) {
        // Ensure popover stays focused after showing
        keepPopoverFocused()
        startFocusTimer()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // Handle file URLs (double-clicking .l1nk files)
            if url.isFileURL && url.pathExtension.lowercased() == "l1nk" {
                handleFile(at: url)
            }
        }
    }
    
    /// Fallback for older file opening mechanism
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if url.pathExtension.lowercased() == "l1nk" {
            handleFile(at: url)
            return true
        }
        return false
    }
    
    /// Handle files passed at launch
    func application(_ application: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            if url.pathExtension.lowercased() == "l1nk" {
                handleFile(at: url)
            }
        }
    }
    
    // MARK: - Service Handler
    @objc func createLinkHere(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        // 1. Get the folder path from the pasteboard
        guard let types = pboard.types, types.contains(.fileURL) || types.contains(.init("NSFilenamesPboardType")),
              let propertyList = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String],
              let folderPath = propertyList.first else {
            error.pointee = "Could not find folder path."
            return
        }
        
        // 2. Get URL from general pasteboard (Clipboard)
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
             // If general clipboard is empty, maybe try to be smart, but user expects clipboard URL
             return
        }
        
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            // Not a valid URL
            return
        }
        
        // 3. Create file in that folder
        let filename = (url.host ?? "link") + ".l1nk"
        let destinationURL = URL(fileURLWithPath: folderPath).appendingPathComponent(filename)
        
        // Avoid overwrite?
        let uniqueURL = generateUniqueURL(for: destinationURL)
        
        do {
            try trimmed.write(to: uniqueURL, atomically: true, encoding: .utf8)
            // success
        } catch {
            print("Failed to write file from service: \(error)")
        }
    }
    
    private func generateUniqueURL(for url: URL) -> URL {
        var newURL = url
        var counter = 1
        let ext = newURL.pathExtension
        let base = newURL.deletingPathExtension().path
        
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = URL(fileURLWithPath: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return newURL
    }
    
    // MARK: - File Handling
    
    func handleFile(at url: URL) {
        // 1. Read content
        var content = ""
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Failed to read file: \(error)")
            // If failed to read, it might be empty or new, verify if existing?
        }
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. If valid URL, open it and exit
        if let link = URL(string: trimmed), link.scheme != nil {
            // Log for debugging
            print("Opening URL: \(link)")
            
            // Check for YouTube Custom App
            let isYT = link.host?.contains("youtube.com") == true || link.host?.contains("youtu.be") == true
            let useCustom = UserDefaults.standard.bool(forKey: "useCustomYouTubeApp")
            let customPath = UserDefaults.standard.string(forKey: "customYouTubeAppPath")
            
            if isYT, useCustom, let appPath = customPath, !appPath.isEmpty {
                let appURL = URL(fileURLWithPath: appPath)
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                
                NSWorkspace.shared.open([link], withApplicationAt: appURL, configuration: config) { app, error in
                    if let error = error {
                        print("Error opening with custom app: \(error)")
                        // Fallback to default
                         NSWorkspace.shared.open(link)
                    }
                }
            } else {
                // Default Open
                NSWorkspace.shared.open(link, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                    if let error = error {
                         print("Error opening URL: \(error)")
                    }
                }
            }
            return
        }
        
        // 3. If empty or invalid, try to update from clipboard
        attemptUpdateFromClipboard(for: url)
    }
    
    func attemptUpdateFromClipboard(for fileURL: URL) {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            return // No text in clipboard
        }
        
        let trimmedClipboard = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if clipboard content looks like a URL
        if let validURL = URL(string: trimmedClipboard), validURL.scheme != nil {
            do {
                try trimmedClipboard.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Updated file with URL from clipboard: \(trimmedClipboard)")
                
                // Now open it
                NSWorkspace.shared.open(validURL)
    
            } catch {
                print("Failed to write to file: \(error)")
                // If we can't write, we simply show the UI
            }
        } else {
            // Clipboard doesn't have a URL, show UI
            print("Clipboard does not contain a valid URL")
        }
    }
}
