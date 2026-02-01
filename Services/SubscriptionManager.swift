import Foundation
import SwiftUI

/// Pro purchase status
enum PurchaseStatus: String, Codable {
    case purchased
    case notPurchased
    
    var isPro: Bool {
        return self == .purchased
    }
}

/// Manages Pro purchase using Stripe Payment Links
/// No backend required - uses Stripe's hosted payment page
///
/// Product ID: prod_TtmiigeQKTvMHg
/// Price ID: price_1Svz8iBwx0wSGNq263sqm4gx
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var purchaseStatus: PurchaseStatus = .notPurchased
    @Published var purchaseDate: Date?
    
    // MARK: - Stripe Configuration
    
    /// Stripe Payment Link URL
    private let paymentLinkURL = "https://buy.stripe.com/bJe4gyboHboSc8427NaMU01"
    
    /// Pro price display
    let proPrice = "$2.99"
    
    // MARK: - UserDefaults Keys
    
    private let purchaseStatusKey = "stripe_purchase_status"
    private let purchaseDateKey = "stripe_purchase_date"
    private let purchaseEmailKey = "stripe_purchase_email"
    
    // MARK: - Initialization
    
    private init() {
        loadCachedPurchase()
    }
    
    // MARK: - Purchase Management
    
    /// Load cached purchase data from UserDefaults
    private func loadCachedPurchase() {
        if let statusRaw = UserDefaults.standard.string(forKey: purchaseStatusKey),
           let status = PurchaseStatus(rawValue: statusRaw) {
            purchaseStatus = status
        }
        
        if let date = UserDefaults.standard.object(forKey: purchaseDateKey) as? Date {
            purchaseDate = date
        }
    }
    
    /// Save purchase data to UserDefaults
    private func cachePurchase() {
        UserDefaults.standard.set(purchaseStatus.rawValue, forKey: purchaseStatusKey)
        if let date = purchaseDate {
            UserDefaults.standard.set(date, forKey: purchaseDateKey)
        }
    }
    
    /// Check if user has purchased Pro
    var isPro: Bool {
        return purchaseStatus.isPro
    }
    
    // MARK: - Purchase Flow
    
    /// Open Stripe Payment Link in browser (recommended for payment security)
    func openPaymentLink() {
        var urlString = paymentLinkURL
        
        // Pre-fill customer email if available
        if let email = AuthManager.shared.userEmail {
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            urlString += "?prefilled_email=\(encodedEmail)"
        }
        
        // Add client reference ID for tracking (user's Apple ID identifier)
        if let userId = AuthManager.shared.userIdentifier {
            let separator = urlString.contains("?") ? "&" : "?"
            urlString += "\(separator)client_reference_id=\(userId)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Mark purchase as complete (call after user confirms they paid)
    func confirmPurchase() {
        purchaseStatus = .purchased
        purchaseDate = Date()
        cachePurchase()
        ProManager.shared.updateFromPurchase(isPro: true, purchaseDate: purchaseDate)
    }
    
    /// Verify purchase with receipt/email (manual verification)
    func verifyPurchase(email: String) {
        // Store the email for reference
        UserDefaults.standard.set(email, forKey: purchaseEmailKey)
        
        // Mark as purchased
        confirmPurchase()
    }
    
    // MARK: - Development Helpers
    
    /// For testing: simulate a Pro purchase
    func simulateProPurchase() {
        purchaseStatus = .purchased
        purchaseDate = Date()
        cachePurchase()
        ProManager.shared.updateFromPurchase(isPro: true, purchaseDate: purchaseDate)
    }
    
    /// For testing: reset to free
    func resetToFree() {
        purchaseStatus = .notPurchased
        purchaseDate = nil
        UserDefaults.standard.removeObject(forKey: purchaseStatusKey)
        UserDefaults.standard.removeObject(forKey: purchaseDateKey)
        UserDefaults.standard.removeObject(forKey: purchaseEmailKey)
        ProManager.shared.updateFromPurchase(isPro: false, purchaseDate: nil)
    }
}
