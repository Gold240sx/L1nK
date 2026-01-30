import SwiftUI
import AppKit

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

@main
struct L1nkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
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

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    var eventMonitor: EventMonitor?
    var focusTimer: Timer?
    
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Service
        NSApp.servicesProvider = self
        
        // Setup Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
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
        if popover.isShown {
            NSApp.activate(ignoringOtherApps: true)
            // Force the popover to update its appearance
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
            // Keep popover focused
            DispatchQueue.main.async {
                self.keepPopoverFocused()
            }
        }
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        // Keep popover focused when app becomes active
        if popover.isShown {
            reactivatePopover()
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
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
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
    }
    
    func keepPopoverFocused() {
        // Access the popover's window and keep it key/main
        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.makeKey()
            popoverWindow.makeMain()
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
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            if self.popover.isShown {
                // Keep popover focused
                self.keepPopoverFocused()
                
                // Check if click is outside popover
                if let popoverWindow = self.popover.contentViewController?.view.window {
                    let windowLocation = popoverWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                    
                    if !popoverWindow.frame.contains(windowLocation) {
                        // Click is outside popover, close it
                        self.popover.performClose(nil)
                        self.eventMonitor?.stop()
                    }
                } else {
                    // Popover window not found, close anyway
                    self.popover.performClose(nil)
                    self.eventMonitor?.stop()
                }
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
        // Keep popover focused
        DispatchQueue.main.async {
            self.keepPopoverFocused()
        }
    }
    
    func popoverDidShow(_ notification: Notification) {
        // Ensure popover stays focused after showing
        keepPopoverFocused()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let fileURL = urls.first else { return }
        
        // Handle the file
        handleFile(at: fileURL)
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
