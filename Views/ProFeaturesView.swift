import SwiftUI

struct ProFeaturesView: View {
    @StateObject private var proManager = ProManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            if proManager.isPro {
                // Show Persistent Tabs when Pro
                PersistentTabsView()
                    .frame(width: 360, height: 420)
            } else {
                // Non-Pro User View - show upgrade prompt
                VStack(spacing: 28) {
                    Spacer()
                    upgradePromptView
                    Spacer()
                }
                .frame(width: 360, height: 420)
            }
            
            // Bottom bar with buttons
            HStack(spacing: 0) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Quit")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .separatorColor).opacity(0.1))
        }
    }
    
    // MARK: - Upgrade Prompt View
    
    private var upgradePromptView: some View {
        VStack(spacing: 24) {
            // Star Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Go Pro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Unlock all premium features")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(subscriptionManager.proPrice)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 8)
            }
            
            // Learn More / Upgrade button - opens Welcome screen
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("ShowWelcomeWindow"), object: nil)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Learn More & Upgrade")
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
            .padding(.horizontal, 40)
            
            // User button if signed in
            if authManager.isSignedIn {
                UserButton()
            }
        }
    }
}
