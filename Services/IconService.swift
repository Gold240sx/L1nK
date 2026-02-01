import Foundation
import AppKit
import SwiftUI

class IconService {
    static let shared = IconService()
    
    private init() {}
    
    /// Check if generic icons mode is enabled (for App Store compliance)
    private var useGenericIcons: Bool {
        UserDefaults.standard.bool(forKey: "useGenericIcons")
    }
    
    func applyIcon(type: IconType, to url: URL) {
        guard type != .none else { return }
        
        let iconImage: NSImage?
        
        if useGenericIcons {
            // Use SF Symbol-based generic icons (App Store compliant)
            iconImage = generateGenericIcon(for: type)
        } else {
            // Use branded icons
            iconImage = loadBrandedIcon(for: type)
        }
        
        if let image = iconImage {
            let success = NSWorkspace.shared.setIcon(image, forFile: url.path)
            if success {
                print("Successfully applied icon to \(url.lastPathComponent)")
            } else {
                print("Failed to apply icon to file")
            }
        } else {
            print("Could not load icon for type: \(type)")
        }
    }
    
    private func loadBrandedIcon(for type: IconType) -> NSImage? {
        var iconName: String?
        switch type {
        case .youtube: iconName = "YouTubeIcon"
        case .github: iconName = "GitHubIcon"
        case .appstore: iconName = "AppStoreIcon"
        case .vimeo: iconName = "VimeoIcon"
        case .amazon: iconName = "AmazonIcon"
        case .ebay: iconName = "EbayIcon"
        case .pinterest: iconName = "PinterestIcon"
        case .steam: iconName = "SteamIcon"
        case .xbox: iconName = "XboxIcon"
        case .playstation: iconName = "PlayStationIcon"
        case .bestbuy: iconName = "BestBuyIcon"
        case .none: return nil
        }
        
        guard let name = iconName else { return nil }
        return loadIcon(named: name)
    }
    
    /// Generate App Store-compliant icons using SF Symbols
    private func generateGenericIcon(for type: IconType) -> NSImage? {
        let config: (symbol: String, color: NSColor)
        
        switch type {
        case .youtube:
            config = ("play.rectangle.fill", NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
        case .github:
            config = ("chevron.left.forwardslash.chevron.right", NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0))
        case .appstore:
            config = ("arrow.down.app.fill", NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0))
        case .vimeo:
            config = ("play.circle.fill", NSColor(red: 0.1, green: 0.72, blue: 0.9, alpha: 1.0))
        case .amazon:
            config = ("shippingbox.fill", NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0))
        case .ebay:
            config = ("tag.fill", NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        case .pinterest:
            config = ("pin.fill", NSColor(red: 0.9, green: 0.1, blue: 0.2, alpha: 1.0))
        case .steam:
            config = ("gamecontroller.fill", NSColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 1.0))
        case .xbox:
            config = ("xmark.circle.fill", NSColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0))
        case .playstation:
            config = ("gamecontroller.fill", NSColor(red: 0.0, green: 0.32, blue: 0.65, alpha: 1.0))
        case .bestbuy:
            config = ("bag.fill", NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0))
        case .none:
            return nil
        }
        
        return renderSFSymbolIcon(symbol: config.symbol, color: config.color)
    }
    
    /// Render an SF Symbol as an NSImage suitable for file icons
    private func renderSFSymbolIcon(symbol: String, color: NSColor, size: CGFloat = 512) -> NSImage? {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .medium)
        
        guard let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig) else {
            return nil
        }
        
        // Create a new image with the symbol centered on a rounded rect background
        let finalImage = NSImage(size: NSSize(width: size, height: size))
        
        finalImage.lockFocus()
        
        // Draw rounded rectangle background
        let bgRect = NSRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.15, yRadius: size * 0.15)
        
        // Gradient background
        let lighterColor = color.blended(withFraction: 0.3, of: .white) ?? color
        let gradient = NSGradient(starting: lighterColor, ending: color)
        gradient?.draw(in: bgPath, angle: -45)
        
        // Draw symbol in white, centered
        let symbolSize = symbolImage.size
        let symbolRect = NSRect(
            x: (size - symbolSize.width) / 2,
            y: (size - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        
        // Tint the symbol white
        NSColor.white.set()
        symbolImage.draw(in: symbolRect, from: .zero, operation: .destinationIn, fraction: 1.0)
        
        // Draw the white symbol
        let tintedSymbol = NSImage(size: symbolSize)
        tintedSymbol.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: symbolSize).fill()
        symbolImage.draw(in: NSRect(origin: .zero, size: symbolSize), from: .zero, operation: .destinationIn, fraction: 1.0)
        tintedSymbol.unlockFocus()
        
        tintedSymbol.draw(in: symbolRect)
        
        finalImage.unlockFocus()
        
        return finalImage
    }
    
    private func loadIcon(named name: String) -> NSImage? {
        // Method 1: Try NSImage(named:) for asset catalog images
        if let image = NSImage(named: name) {
            return image
        }
        
        // Method 2: Try loading .icns from bundle resources
        if let iconURL = Bundle.main.url(forResource: name, withExtension: "icns") {
            if let image = NSImage(contentsOf: iconURL) {
                return image
            }
        }
        
        // Method 3: Try loading from Assets folder in bundle
        if let resourcePath = Bundle.main.resourcePath {
            let icnsPath = (resourcePath as NSString).appendingPathComponent("\(name).icns")
            if FileManager.default.fileExists(atPath: icnsPath) {
                return NSImage(contentsOfFile: icnsPath)
            }
        }
        
        // Method 4: Try loading PNG
        if let iconURL = Bundle.main.url(forResource: name, withExtension: "png") {
            if let image = NSImage(contentsOf: iconURL) {
                return image
            }
        }
        
        return nil
    }
}
