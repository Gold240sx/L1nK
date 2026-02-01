import SwiftUI
import AppKit

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @State private var currentPage: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button in top right
            HStack {
                Spacer()
                Button(action: {
                    dismissWelcome()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Page content with custom page view
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Page 1: Features
                    FeaturesPage()
                        .frame(width: geometry.size.width)
                        .offset(x: -CGFloat(currentPage) * geometry.size.width)
                    
                    // Page 2: How To Use
                    HowToPage(dismissAction: dismissWelcome)
                        .frame(width: geometry.size.width)
                        .offset(x: -CGFloat(currentPage) * geometry.size.width)
                    
                    // Page 3: Pro Features
                    ProFeaturesWelcomePage(dismissAction: dismissWelcome)
                        .frame(width: geometry.size.width)
                        .offset(x: -CGFloat(currentPage) * geometry.size.width)
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
            
            // Custom navigation buttons
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Previous")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                    }
                    
                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Button(action: {
                                withAnimation {
                                    currentPage = index
                                }
                            }) {
                                Circle()
                                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if currentPage < 2 {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                    }
                }
                
                // Skip link - always visible
                Button(action: {
                    dismissWelcome()
                }) {
                    Text("Skip and use basic features")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 600, height: 700)
        .background(Color.clear)
    }
    
    private func dismissWelcome() {
        hasSeenWelcome = true
        isPresented = false
        NotificationCenter.default.post(name: NSNotification.Name("CloseWelcomeWindow"), object: nil)
    }
}

struct FeaturesPage: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    // App Icon with gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)
                        
                        Group {
                            if let appIcon = NSImage(named: "AppIconDefault")
                                ?? NSImage(named: "AppIconDisplay")
                                ?? NSImage(named: "AppIcon") {
                                Image(nsImage: appIcon)
                                    .resizable()
                            } else {
                                Image(nsImage: NSApp.applicationIconImage)
                                    .resizable()
                            }
                        }
                        .frame(width: 80, height: 80)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Welcome to L1nK")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Create link files from any URL")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("Version \(appVersion)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                    // Features Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Features")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            FeatureRow(
                                icon: "link.badge.plus",
                                iconColor: .blue,
                                title: "Universal Link Files with Custom File Type",
                                description: "L1nK comes with its own file type (.l1nk) that makes URLs first-class citizens in your file system. Create .l1nk files that open in your default browser with a simple double-click - no need to copy and paste."
                            )
                            
                            FeatureRow(
                                icon: "textformat",
                                iconColor: .purple,
                                title: "Smart Naming",
                                description: "Automatically names files based on content (YouTube titles, GitHub repos, etc.)"
                            )
                            
                            FeatureRow(
                                icon: "paintbrush.fill",
                                iconColor: .orange,
                                title: "Custom Icons",
                                description: "Special icons for YouTube, GitHub, App Store, and Vimeo links"
                            )
                            
                            FeatureRow(
                                icon: "menubar.rectangle",
                                iconColor: .green,
                                title: "Menu Bar Access",
                                description: "Quick access from your menu bar - always at your fingertips"
                            )
                            
                            FeatureRow(
                                icon: "folder.fill",
                                iconColor: .cyan,
                                title: "Flexible Saving",
                                description: "Choose where to save or set a default directory. Create link files in seconds from your clipboard or drag & drop"
                            )
                            
                            FeatureRow(
                                icon: "arrow.down.circle.fill",
                                iconColor: .blue,
                                title: "Easy Updates",
                                description: "Automatic updates keep your app current without hassle - you'll always have the latest features"
                            )
                            
                            FeatureRow(
                                icon: "bolt.fill",
                                iconColor: .green,
                                title: "Lightweight",
                                description: "Runs efficiently in the background, using minimal system resources"
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }
}

struct HowToPage: View {
    let dismissAction: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 8) {
                        Text("How To Use")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Get started in just a few steps")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // How To Section
                VStack(alignment: .leading, spacing: 24) {
                    HowToStep(
                        number: "1",
                        title: "Copy a URL",
                        description: "Copy any URL from your browser or anywhere else"
                    )
                    
                    HowToStep(
                        number: "2",
                        title: "Create Link File",
                        description: "Click the menu bar icon and select \"Create from Clipboard\""
                    )
                    
                    HowToStep(
                        number: "3",
                        title: "Save & Use",
                        description: "Choose where to save your .l1nk file, then double-click it anytime to open"
                    )
                    
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                        
                        Text("Tip: You can also drag & drop URLs onto the menu bar icon!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.leading, 48)
                }
                .padding(.horizontal, 24)
                
                    // Get Started Button (Skip sign in, use basic features)
                    VStack(spacing: 12) {
                        Button(action: dismissAction) {
                            HStack(spacing: 10) {
                                Text("Get Started")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Text("Use basic features without signing in")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct HowToStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pro Features Welcome Page

struct ProFeaturesWelcomePage: View {
    let dismissAction: () -> Void
    @StateObject private var proManager = ProManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
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
                            .blur(radius: 25)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
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
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        if proManager.isPro {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                Text("Pro Unlocked")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("One-time purchase, lifetime access")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Price (if not Pro)
                if !proManager.isPro {
                    VStack(spacing: 4) {
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
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Pro Features List
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pro Features")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "sparkles",
                            iconColor: .purple,
                            title: "Advanced Features",
                            description: "Access to premium functionality and customization"
                        )
                        
                        FeatureRow(
                            icon: "bolt.fill",
                            iconColor: .blue,
                            title: "Priority Support",
                            description: "Get help faster with priority customer support"
                        )
                        
                        FeatureRow(
                            icon: "crown.fill",
                            iconColor: .orange,
                            title: "Early Access",
                            description: "Be the first to try new features before anyone else"
                        )
                        
                        FeatureRow(
                            icon: "infinity",
                            iconColor: .green,
                            title: "Lifetime Access",
                            description: "One-time purchase, forever yours with all future updates"
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // Action Button
                if proManager.isPro {
                    // Already Pro - Get Started button
                    Button(action: dismissAction) {
                        HStack(spacing: 10) {
                            Text("Get Started")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                } else {
                    // Not Pro - Purchase button
                    VStack(spacing: 12) {
                        Button(action: {
                            subscriptionManager.openPaymentLink()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Upgrade to Pro - \(subscriptionManager.proPrice)")
                                    .font(.system(size: 16, weight: .semibold))
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
                        
                        Button(action: {
                            subscriptionManager.confirmPurchase()
                        }) {
                            Text("Already purchased? Activate Pro")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: dismissAction) {
                            Text("Maybe later")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                    .frame(height: 32)
            }
        }
    }
}
