import SwiftUI
import AuthenticationServices

/// Native Sign in with Apple and Touch ID view
struct SignInView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button at top right
            HStack {
                Spacer()
                Button(action: closeWindow) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Sign In")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Sign in to unlock Pro features")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Authentication buttons
            VStack(spacing: 12) {
                // Touch ID / Face ID button (if available)
                if authManager.canUseTouchID {
                    Button(action: {
                        Task {
                            await authManager.authenticateWithBiometrics()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: authManager.biometricIcon)
                                .font(.system(size: 20, weight: .medium))
                            Text("Sign in with \(authManager.biometricName)")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
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
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 40)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Sign in with Apple button
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleSignInResult(result)
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal, 40)
                
                // Error message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Loading indicator
                if authManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 4) {
                if authManager.canUseTouchID {
                    Text("Use \(authManager.biometricName) for quick sign-in")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text("Your credentials are stored securely on this device.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: authManager.canUseTouchID ? 500 : 450)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                closeWindow()
            }
        }
    }
    
    private func closeWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("CloseAuthWindow"), object: nil)
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = credential.user
                let email = credential.email
                
                var fullName: String? = nil
                if let nameComponents = credential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    fullName = formatter.string(from: nameComponents)
                }
                
                // Save credentials through AuthManager
                Task { @MainActor in
                    AuthManager.shared.isSignedIn = true
                    UserDefaults.standard.set(userIdentifier, forKey: "appleUserIdentifier")
                    UserDefaults.standard.set(true, forKey: "hasPreviouslySignedIn")
                    if let email = email {
                        UserDefaults.standard.set(email, forKey: "appleUserEmail")
                    }
                    if let name = fullName {
                        UserDefaults.standard.set(name, forKey: "appleUserName")
                    }
                    closeWindow()
                }
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, no error
                    break
                default:
                    Task { @MainActor in
                        AuthManager.shared.errorMessage = "Sign in failed. Please try again."
                    }
                }
            }
        }
    }
}

/// User button that shows signed-in state
struct UserButton: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        Menu {
            if authManager.isSignedIn {
                Text(authManager.displayName)
                    .font(.system(size: 12))
                
                if let email = authManager.userEmail {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button(action: {
                    authManager.signOut()
                }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    authManager.isSignedIn
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.secondary, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}
