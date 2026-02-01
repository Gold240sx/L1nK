import Foundation
import AppKit
import SwiftUI

/// Manages favicon fetching and caching for persistent tabs
@MainActor
class FaviconManager: ObservableObject {
    static let shared = FaviconManager()
    
    // MARK: - Properties
    
    /// In-memory cache for quick access
    private let memoryCache = NSCache<NSString, NSImage>()
    
    /// Disk cache directory
    private let cacheDirectory: URL
    
    /// Default favicon for when none can be found
    private let defaultFavicon: NSImage
    
    // MARK: - Initialization
    
    private init() {
        // Set up disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheDir.appendingPathComponent("L1nK/Favicons", isDirectory: true)
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Set up memory cache limits
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Create default favicon
        self.defaultFavicon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website") 
            ?? NSImage()
    }
    
    // MARK: - Public Methods
    
    /// Get favicon for a URL, using cache hierarchy
    /// Order: Memory -> Disk -> NSWorkspace -> Google fallback
    func favicon(for urlString: String) async -> NSImage {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return defaultFavicon
        }
        
        // Skip local/invalid hosts
        if isLocalHost(host) {
            return defaultFavicon
        }
        
        let domain = extractDomain(from: host)
        
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: domain as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let diskCached = loadFromDisk(domain: domain) {
            memoryCache.setObject(diskCached, forKey: domain as NSString)
            return diskCached
        }
        
        // 3. Try fetching from web
        if let fetched = await fetchFavicon(for: url, domain: domain) {
            // Cache it
            memoryCache.setObject(fetched, forKey: domain as NSString)
            saveToDisk(image: fetched, domain: domain)
            return fetched
        }
        
        // 4. Fallback to default
        return defaultFavicon
    }
    
    /// Check if host is a local/private address that shouldn't be fetched
    private func isLocalHost(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        
        // Localhost variations
        if lowercased == "localhost" || lowercased == "127.0.0.1" || lowercased == "::1" {
            return true
        }
        
        // Local network ranges
        if lowercased.hasPrefix("192.168.") || lowercased.hasPrefix("10.") {
            return true
        }
        
        // 172.16.0.0 - 172.31.255.255
        if lowercased.hasPrefix("172.") {
            let parts = lowercased.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return true
            }
        }
        
        // No TLD (likely a local hostname)
        if !lowercased.contains(".") {
            return true
        }
        
        // IP addresses without proper domains
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if lowercased.range(of: ipPattern, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    /// Get cached favicon path for SwiftData storage
    func getCachedPath(for urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        
        let domain = extractDomain(from: host)
        let path = diskCachePath(for: domain)
        
        if FileManager.default.fileExists(atPath: path.path) {
            return path.path
        }
        
        return nil
    }
    
    /// Pre-fetch and cache a favicon
    func prefetch(for urlString: String) async {
        _ = await favicon(for: urlString)
    }
    
    /// Clear all cached favicons
    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Private Methods
    
    /// Extract root domain from host
    private func extractDomain(from host: String) -> String {
        // Remove www. prefix
        var domain = host.lowercased()
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        return domain
    }
    
    /// Get disk cache file path for a domain
    private func diskCachePath(for domain: String) -> URL {
        let sanitized = domain.replacingOccurrences(of: "/", with: "_")
                              .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent("\(sanitized).png")
    }
    
    /// Load favicon from disk cache
    private func loadFromDisk(domain: String) -> NSImage? {
        let path = diskCachePath(for: domain)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = NSImage(data: data) else {
            return nil
        }
        return image
    }
    
    /// Save favicon to disk cache
    private func saveToDisk(image: NSImage, domain: String) {
        let path = diskCachePath(for: domain)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        
        try? pngData.write(to: path)
    }
    
    /// Fetch favicon from various sources
    private func fetchFavicon(for url: URL, domain: String) async -> NSImage? {
        // Try standard favicon locations
        let faviconURLs = [
            URL(string: "https://\(domain)/favicon.ico"),
            URL(string: "https://\(domain)/favicon.png"),
            URL(string: "https://www.\(domain)/favicon.ico"),
            // Google's favicon service as fallback
            URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
        ].compactMap { $0 }
        
        for faviconURL in faviconURLs {
            if let image = await downloadImage(from: faviconURL) {
                // Resize to standard size
                return resizeImage(image, to: NSSize(width: 32, height: 32))
            }
        }
        
        return nil
    }
    
    /// Download image from URL
    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data),
                  image.size.width > 0 else {
                return nil
            }
            
            return image
        } catch {
            return nil
        }
    }
    
    /// Resize image to target size
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - SwiftUI View Extension

struct FaviconView: View {
    let urlString: String
    @State private var image: NSImage?
    @StateObject private var manager = FaviconManager.shared
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            image = await manager.favicon(for: urlString)
        }
    }
}
