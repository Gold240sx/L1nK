import Foundation
import Combine

/// Manages Pro upgrade status and features
@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()
    
    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
        }
    }
    
    @Published var purchaseDate: Date?
    
    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        if let date = UserDefaults.standard.object(forKey: "proPurchaseDate") as? Date {
            self.purchaseDate = date
        }
    }
    
    /// Update Pro status from purchase
    func updateFromPurchase(isPro: Bool, purchaseDate: Date?) {
        self.isPro = isPro
        self.purchaseDate = purchaseDate
        if let date = purchaseDate {
            UserDefaults.standard.set(date, forKey: "proPurchaseDate")
        } else {
            UserDefaults.standard.removeObject(forKey: "proPurchaseDate")
        }
    }
    
    /// Upgrade to Pro via Stripe purchase
    func upgradeToPro() {
        // This triggers the purchase flow
        NotificationCenter.default.post(name: NSNotification.Name("ShowSubscriptionView"), object: nil)
    }
    
    /// Downgrade from Pro (for testing)
    func downgradeFromPro() {
        isPro = false
        purchaseDate = nil
        UserDefaults.standard.removeObject(forKey: "proPurchaseDate")
        SubscriptionManager.shared.resetToFree()
    }
    
    /// Format the purchase date for display
    var formattedPurchaseDate: String? {
        guard let date = purchaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
