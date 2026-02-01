import SwiftUI

/// Pro purchase view - one-time payment via Stripe Payment Link
struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var showingConfirmation = false
    @State private var confirmationEmail = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: closeWindow) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            if showingConfirmation {
                confirmationView
            } else {
                purchaseView
            }
        }
        .frame(width: 380, height: 520)
    }
    
    // MARK: - Purchase View
    
    private var purchaseView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .blur(radius: 15)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("Upgrade to Pro")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("One-time purchase, lifetime access")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Price display
                VStack(spacing: 8) {
                    Text(subscriptionManager.proPrice)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("One-time payment")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                // Features List
                VStack(alignment: .leading, spacing: 12) {
                    FeatureCheckRow(text: "Advanced link customization")
                    FeatureCheckRow(text: "Priority customer support")
                    FeatureCheckRow(text: "Early access to new features")
                    FeatureCheckRow(text: "No usage limits")
                    FeatureCheckRow(text: "Lifetime updates included")
                }
                .padding(.horizontal, 24)
                
                // Purchase Button
                VStack(spacing: 16) {
                    Button(action: {
                        subscriptionManager.openPaymentLink()
                        // Show confirmation after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingConfirmation = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Purchase Pro - \(subscriptionManager.proPrice)")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Opens secure Stripe checkout in your browser")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                
                // Already purchased?
                Button(action: {
                    showingConfirmation = true
                }) {
                    Text("Already purchased? Activate Pro")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                // Development testing buttons
                #if DEBUG
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    Text("Development Testing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("Simulate Purchase") {
                            subscriptionManager.simulateProPurchase()
                            closeWindow()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        
                        Button("Reset to Free") {
                            subscriptionManager.resetToFree()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                #endif
                
                // Footer
                VStack(spacing: 4) {
                    Text("Secure payment powered by Stripe")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Confirmation View
    
    private var confirmationView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Complete Your Purchase")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Did you complete the payment in your browser?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Email field (optional - for receipt lookup)
            VStack(alignment: .leading, spacing: 8) {
                Text("Email used for purchase (optional)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("email@example.com", text: $confirmationEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    if !confirmationEmail.isEmpty {
                        subscriptionManager.verifyPurchase(email: confirmationEmail)
                    } else {
                        subscriptionManager.confirmPurchase()
                    }
                    closeWindow()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Yes, Activate Pro")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    showingConfirmation = false
                }) {
                    Text("No, go back")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Help text
            Text("If you haven't paid yet, click 'No, go back'\nand complete the purchase first.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
    }
    
    private func closeWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("CloseSubscriptionWindow"), object: nil)
    }
}

// MARK: - Supporting Views

struct FeatureCheckRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

/// Purchase status display for settings
struct PurchaseStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var proManager = ProManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Status")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(proManager.isPro ? "Pro" : "Free")
                            .font(.system(size: 15, weight: .semibold))
                        
                        if proManager.isPro {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                if !proManager.isPro {
                    Button("Upgrade") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowSubscriptionView"), object: nil)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let purchaseDate = proManager.formattedPurchaseDate {
                Text("Purchased on \(purchaseDate)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        }
    }
}
