import Foundation
import SwiftData
import SwiftUI

/// A folder to organize persistent tabs
@Model
final class TabFolder {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String?
    var iconName: String?
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \PersistentTab.folder)
    var tabs: [PersistentTab]?
    
    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        orderIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
    
    /// SwiftUI Color from hex string
    var color: Color {
        guard let hex = colorHex else {
            return .blue
        }
        return Color(hex: hex) ?? .blue
    }
    
    /// Set color from SwiftUI Color
    func setColor(_ color: Color) {
        self.colorHex = color.toHex()
    }
    
    /// SF Symbol icon name (default: folder.fill)
    var icon: String {
        iconName ?? "folder.fill"
    }
    
    /// Set folder icon
    func setIcon(_ name: String) {
        self.iconName = name
    }
    
    /// Number of non-archived tabs in this folder
    var tabCount: Int {
        tabs?.filter { !$0.archived }.count ?? 0
    }
    
    /// Predefined folder colors
    static let availableColors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .cyan, .indigo
    ]
    
    /// Available folder icons
    static let availableIcons: [String] = [
        "folder.fill",
        "tray.fill",
        "archivebox.fill",
        "briefcase.fill",
        "building.2.fill",
        "house.fill",
        "star.fill",
        "heart.fill",
        "bookmark.fill",
        "tag.fill",
        "flag.fill",
        "bell.fill",
        "lightbulb.fill",
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "gamecontroller.fill",
        "music.note",
        "film.fill",
        "photo.fill",
        "book.fill",
        "graduationcap.fill",
        "cart.fill",
        "creditcard.fill",
        "airplane",
        "car.fill"
    ]
}

// MARK: - Color Extensions for Hex Conversion

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else {
            return nil
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
