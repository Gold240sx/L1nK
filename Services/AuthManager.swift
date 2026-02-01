import Foundation
import AuthenticationServices
import LocalAuthentication
import SwiftUI

/// Manages authentication using native Sign in with Apple and Touch ID
@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    
    @Published var isSignedIn: Bool = false
    @Published var userIdentifier: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var canUseTouchID: Bool = false
    @Published var hasPreviouslySignedIn: Bool = false
    
    // UserDefaults keys
    private let userIdentifierKey = "appleUserIdentifier"
    private let userEmailKey = "appleUserEmail"
    private let userNameKey = "appleUserName"
    private let hasPreviouslySignedInKey = "hasPreviouslySignedIn"
    
    private var authWindow: NSWindow?
    private let laContext = LAContext()
    
    private override init() {
        super.init()
        checkBiometricAvailability()
        loadStoredCredentials()
    }
    
    // MARK: - Biometric Availability
    
    private func checkBiometricAvailability() {
        var error: NSError?
        canUseTouchID = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        hasPreviouslySignedIn = UserDefaults.standard.bool(forKey: hasPreviouslySignedInKey)
    }
    
    /// Returns the type of biometric available (Touch ID, Face ID, or none)
    var biometricType: LABiometryType {
        var error: NSError?
        guard laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return laContext.biometryType
    }
    
    /// Human-readable name for the biometric type
    var biometricName: String {
        switch biometricType {
        case .none:
            return "Biometrics"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }
    
    /// SF Symbol name for the biometric type
    var biometricIcon: String {
        switch biometricType {
        case .none:
            return "person.badge.key"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "person.badge.key"
        }
    }
    
    // MARK: - Credential Management
    
    private func loadStoredCredentials() {
        if let identifier = UserDefaults.standard.string(forKey: userIdentifierKey) {
            userIdentifier = identifier
            userEmail = UserDefaults.standard.string(forKey: userEmailKey)
            userName = UserDefaults.standard.string(forKey: userNameKey)
            isSignedIn = true
            
            // Verify the credential is still valid
            Task {
                await checkCredentialState()
            }
        }
    }
    
    private func saveCredentials(identifier: String, email: String?, name: String?) {
        UserDefaults.standard.set(identifier, forKey: userIdentifierKey)
        UserDefaults.standard.set(true, forKey: hasPreviouslySignedInKey)
        if let email = email {
            UserDefaults.standard.set(email, forKey: userEmailKey)
        }
        if let name = name {
            UserDefaults.standard.set(name, forKey: userNameKey)
        }
        
        userIdentifier = identifier
        userEmail = email
        userName = name
        isSignedIn = true
        hasPreviouslySignedIn = true
    }
    
    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: userIdentifierKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        // Keep hasPreviouslySignedIn so Touch ID can be used for re-auth
        
        userIdentifier = nil
        userEmail = nil
        userName = nil
        isSignedIn = false
    }
    
    // MARK: - Touch ID / Biometric Authentication
    
    /// Authenticate using Touch ID (or Face ID on supported devices)
    func authenticateWithBiometrics() async -> Bool {
        guard canUseTouchID else {
            await MainActor.run {
                errorMessage = "\(biometricName) is not available on this device."
            }
            return false
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        let reason = "Sign in to L1nK with \(biometricName)"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            await MainActor.run {
                isLoading = false
                
                if success {
                    // If user has previously signed in with Apple, restore their session
                    if let storedIdentifier = UserDefaults.standard.string(forKey: userIdentifierKey) {
                        userIdentifier = storedIdentifier
                        userEmail = UserDefaults.standard.string(forKey: userEmailKey)
                        userName = UserDefaults.standard.string(forKey: userNameKey)
                        isSignedIn = true
                        NotificationCenter.default.post(name: NSNotification.Name("CloseAuthWindow"), object: nil)
                    } else {
                        // No previous Apple sign-in, create a biometric-only session
                        userIdentifier = "biometric-\(UUID().uuidString)"
                        userName = "Touch ID User"
                        isSignedIn = true
                        hasPreviouslySignedIn = true
                        UserDefaults.standard.set(true, forKey: hasPreviouslySignedInKey)
                        NotificationCenter.default.post(name: NSNotification.Name("CloseAuthWindow"), object: nil)
                    }
                }
            }
            
            return success
        } catch let error as LAError {
            await MainActor.run {
                isLoading = false
                
                switch error.code {
                case .userCancel:
                    // User canceled, no error message needed
                    break
                case .userFallback:
                    // User chose to enter password
                    errorMessage = "Please use Sign in with Apple instead."
                case .biometryNotAvailable:
                    errorMessage = "\(biometricName) is not available."
                case .biometryNotEnrolled:
                    errorMessage = "No \(biometricName) enrolled. Please set up \(biometricName) in System Settings."
                case .biometryLockout:
                    errorMessage = "\(biometricName) is locked. Please try again later."
                case .authenticationFailed:
                    errorMessage = "\(biometricName) authentication failed."
                default:
                    errorMessage = "Authentication error: \(error.localizedDescription)"
                }
            }
            return false
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func signOut() {
        clearCredentials()
    }
    
    // MARK: - Credential State Check
    
    func checkCredentialState() async {
        guard let userIdentifier = userIdentifier else { return }
        
        let provider = ASAuthorizationAppleIDProvider()
        
        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)
            
            await MainActor.run {
                switch state {
                case .authorized:
                    // Credential is still valid
                    break
                case .revoked, .notFound:
                    // Credential has been revoked or not found, sign out
                    self.clearCredentials()
                case .transferred:
                    // User transferred to a different Apple ID
                    self.clearCredentials()
                @unknown default:
                    break
                }
            }
        } catch {
            print("Error checking credential state: \(error)")
        }
    }
    
    // MARK: - Display Name
    
    var displayName: String {
        if let name = userName, !name.isEmpty {
            return name
        } else if let email = userEmail {
            return email
        } else {
            return "User"
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            isLoading = false
            
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = credential.user
                let email = credential.email
                
                var fullName: String? = nil
                if let nameComponents = credential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    fullName = formatter.string(from: nameComponents)
                }
                
                saveCredentials(identifier: userIdentifier, email: email, name: fullName)
                
                // Close auth window if open
                NotificationCenter.default.post(name: NSNotification.Name("CloseAuthWindow"), object: nil)
            }
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, no error message needed
                    break
                case .failed:
                    errorMessage = "Authorization failed. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple."
                case .notHandled:
                    errorMessage = "Request not handled."
                case .unknown:
                    errorMessage = "An unknown error occurred."
                case .notInteractive:
                    errorMessage = "Request requires user interaction."
                case .matchedExcludedCredential:
                    errorMessage = "This credential has been excluded."
                case .credentialImport:
                    errorMessage = "Credential import error."
                case .credentialExport:
                    errorMessage = "Credential export error."
                case .preferSignInWithApple:
                    errorMessage = "Please use Sign in with Apple."
                case .deviceNotConfiguredForPasskeyCreation:
                    errorMessage = "Device is not configured for passkey creation."
                @unknown default:
                    errorMessage = "An error occurred."
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window or create one
        // Use MainActor.assumeIsolated since this is always called on main thread by ASAuthorizationController
        return MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
        }
    }
}
