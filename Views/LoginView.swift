import SwiftUI
import LocalAuthentication
import AuthenticationServices
import CryptoKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Try to import Firebase - if it fails, we'll handle it at runtime
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@available(iOS 17.0, macOS 14.0, *)
struct LoginView: View {
    @Binding var hasLoggedIn: Bool
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var showMainApp = false
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var biometricType: LABiometryType = .none
    @AppStorage("hasPreviouslyLoggedIn") private var hasPreviouslyLoggedIn = false
    
    // Email/Password authentication
    @State private var showEmailPasswordAuth = false
    @State private var isSignUpMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showPasswordResetSent = false
    @State private var showPasswordResetAlert = false

    // Apple Sign-In nonce (required for Firebase Auth with Apple)
    @State private var currentNonce: String?
    /// Retains the coordinator until Sign in with Apple flow completes.
    @State private var appleSignInCoordinator: AppleSignInCoordinator?
    
    init(hasLoggedIn: Binding<Bool> = .constant(false)) {
        _hasLoggedIn = hasLoggedIn
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient Background - more opaque on macOS so sheet stands out from landing page
                Group {
                    #if os(macOS)
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.95),
                            Color.blue.opacity(0.95),
                            Color.purple.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    #else
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.9),
                            Color.purple.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    #endif
                }
                .ignoresSafeArea(.all, edges: .all)
                
                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -150)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                
                #if os(macOS)
                // Red close button to dismiss sheet and return to main window
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.red.opacity(0.9)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        .accessibilityHint("Return to main window")
                        Spacer()
                    }
                    .padding(.top, max(geometry.safeAreaInsets.top, 12))
                    .padding(.leading, 20)
                    Spacer()
                }
                .allowsHitTesting(true)
                .zIndex(10)
                #endif
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Top safe area padding
                        Spacer()
                            .frame(height: max(geometry.safeAreaInsets.top, 20))
                        
                        // App Icon
                        AppIconView()
                            .frame(width: 100, height: 100)
                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                            .padding(.top, 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            
                            Text("Sign in to continue your faith journey")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Login Card with glassmorphism
                        VStack(spacing: 24) {
                            if let error = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(error)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.3))
                                .cornerRadius(12)
                            }
                            
                            // Email/Password Authentication Section — Apple and Email always first so "Sign in with Apple" is never confused with Touch ID
                            if showEmailPasswordAuth {
                                // Always show the form - let FirebaseInitializer handle availability
                                // The form will show appropriate errors if Firebase isn't available
                                emailPasswordAuthView
                            } else {
                                // Sign in with Apple — same design as Email and Demo (per App Store guideline)
                                Button(action: { performAppleSignIn() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "apple.logo")
                                        Text("Sign in with Apple")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 300, height: 44)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.black, Color.black.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                }
                                .buttonStyle(.plain)
                                .disabled(isAuthenticating)
                                .accessibilityLabel("Sign in with Apple")
                                .accessibilityHint("Signs you in with your Apple ID. Your device may ask for Touch ID or password to verify.")
                                if biometricType != .none {
                                    Text("Your device may ask for Touch ID or password to verify your Apple ID.")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.85))
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 4)
                                }
                                
                                // Sign in with Email — same size as Sign in with Apple (300×44)
                                Button(action: {
                                    withAnimation {
                                        showEmailPasswordAuth = true
                                    }
                                }) {
                                    Text("Sign in with Email")
                                        .font(.headline)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 300, height: 44)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                }
                                .padding(.top, 8)
                                .accessibilityLabel("Sign in with Email")
                                .accessibilityHint("Sign in or create an account using email and password")
                            }
                            
                            // Quick unlock with Touch ID / Face ID — only for returning users, clearly separate from Sign in with Apple
                            if biometricType != .none {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                if hasPreviouslyLoggedIn {
                                    Text("Already signed in? Unlock with biometrics")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                biometricButton
                                    .disabled(isAuthenticating)
                            }
                            
                            // Demo button for simulator/testing (Sign in with Apple doesn't work in simulator)
                            // Always show for now to help with testing - can be made conditional later
                            Divider()
                                .background(Color.white.opacity(0.3))
                            
                            Button(action: {
                                print("🔄 [LOGIN] Try Demo button tapped")
                                // For simulator/testing, use demo mode with shared test user
                                // This allows testing cross-device sync without real Apple Sign In
                                isAuthenticating = true
                                
                                Task {
                                    // Set logged in state
                                    await MainActor.run {
                                        hasLoggedIn = true
                                        hasPreviouslyLoggedIn = true
                                        isAuthenticating = false
                                    }
                                    
                                    // Configure Firebase sync with test user ID
                                    // The sync service will use simulator-test-user-shared for testing
                                    print("✅ [DEMO] Demo mode activated for testing")
                                    print("✅ [DEMO] Using shared test user ID for cross-device sync")
                                    print("✅ [DEMO] Firebase sync will work with test user: simulator-test-user-shared")
                                    
                                    // IMPORTANT: Test Firebase connection FIRST to create collections
                                    // This will create both a top-level testConnection collection AND
                                    // a user-specific collection at users/simulator-test-user-shared/testConnection
                                    print("🔄 [DEMO] Testing Firebase connection and creating collections...")
                                    await FirebaseSyncService.shared.testFirebaseConnection()
                                    
                                    // Wait a moment for the write to complete
                                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                    
                                    // Now sync existing data (only when Firebase is linked for this target)
                                    print("🔄 [DEMO] Syncing existing data to Firebase...")
                                    #if canImport(FirebaseFirestore)
                                    await FirebaseSyncService.shared.syncAllData()
                                    #endif
                                    
                                    print("✅ [DEMO] Demo mode setup complete!")
                                    print("✅ [DEMO] Check Firebase Console - you should see:")
                                    print("   1. 'testConnection' collection (top-level)")
                                    print("   2. 'users' collection → 'simulator-test-user-shared' → 'testConnection' subcollection")
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Try Demo")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 300, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isAuthenticating)
                            .accessibilityLabel("Try Demo")
                            .accessibilityHint("Sign in as a test user for simulator or testing")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(
                            Group {
                                #if os(macOS)
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                #else
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(.ultraThinMaterial)
                                #endif
                            }
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 24)
                        
                        // Bottom safe area padding
                        Spacer()
                            .frame(height: max(geometry.safeAreaInsets.bottom + 20, 40))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
        .onAppear {
            // Ensure Firebase is initialized before any Auth call paths.
            // This prevents “Failed to get FirebaseApp instance” style errors.
            ensureFirebaseInitialized()
            checkBiometricType()
            
            // Check Firebase availability and log status
            #if canImport(FirebaseAuth)
            if FirebaseInitializer.shared.isConfigured {
                print("✅ [LOGIN] Firebase Auth is available and configured")
            } else {
                print("⚠️ [LOGIN] Firebase Auth can be imported but not configured")
                print("⚠️ [LOGIN] Check GoogleService-Info.plist")
            }
            #else
            print("❌ [LOGIN] FirebaseAuth cannot be imported at compile time")
            print("❌ [LOGIN] Packages are linked but not being imported")
            print("❌ [LOGIN] Solution: Clean build (⇧⌘K) and rebuild (⌘B)")
            #endif
        }
    }

    private func ensureFirebaseInitialized() {
        // FirebaseInitializer itself uses compile-time guards; calling it is safe even if packages aren't linked.
        if !FirebaseInitializer.shared.isConfigured {
            FirebaseInitializer.shared.initialize()
        }
    }
    
    @ViewBuilder
    private var biometricButton: some View {
        if biometricType == .faceID {
            Button(action: { handleFaceIDLogin() }) {
                HStack(spacing: 12) {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "faceid")
                            .font(.title3)
                    }
                    Text(isAuthenticating ? "Authenticating..." : "Sign in with Face ID")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        } else if biometricType == .touchID {
            Button(action: { handleTouchIDLogin() }) {
                HStack(spacing: 12) {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "touchid")
                            .font(.title3)
                    }
                    Text(isAuthenticating ? "Authenticating..." : "Sign in with Touch ID")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    // MARK: - Biometric Type Check
    
    private func checkBiometricType() {
        #if targetEnvironment(simulator)
        // Simulator doesn't fully support biometric authentication
        // This prevents MCPasscodeManager errors in simulator
        biometricType = .none
        #else
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
        #endif
    }
    
    // MARK: - Login Handlers
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        print("🔍 [APPLE SIGN IN] handleAppleSignIn called")
        isAuthenticating = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            print("✅ [APPLE SIGN IN] Authorization received")
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                print("✅ [APPLE SIGN IN] Apple Sign In successful")
                print("✅ [APPLE SIGN IN] User ID: \(appleIDCredential.user)")
                print("✅ [APPLE SIGN IN] Email: \(appleIDCredential.email ?? "not provided")")
                print("✅ [APPLE SIGN IN] Full Name: \(appleIDCredential.fullName?.givenName ?? "not provided")")
                Task { @MainActor in
                    let nonceToUse = currentNonce
                    await signInToFirebaseWithApple(appleIDCredential: appleIDCredential, nonce: nonceToUse)
                }
            } else {
                let credentialType = type(of: authorization.credential)
                print("❌ [APPLE SIGN IN] Invalid credential type: \(credentialType)")
                Task { @MainActor in
                    isAuthenticating = false
                    errorMessage = "Invalid credential type received."
                    print("❌ [APPLE SIGN IN] Invalid credential type")
                }
            }
        case .failure(let error):
            Task { @MainActor in
                isAuthenticating = false
                
                // Log detailed error information for debugging
                print("❌ [APPLE SIGN IN] Sign in failed")
                print("❌ [APPLE SIGN IN] Error: \(error)")
                print("❌ [APPLE SIGN IN] Error localized: \(error.localizedDescription)")
                
                let nsError = error as NSError
                print("❌ [APPLE SIGN IN] Error domain: \(nsError.domain)")
                print("❌ [APPLE SIGN IN] Error code: \(nsError.code)")
                print("❌ [APPLE SIGN IN] Error userInfo: \(nsError.userInfo)")
                
                // Check if we're in simulator - authentication errors are expected
                #if targetEnvironment(simulator)
                if let authError = error as? ASAuthorizationError, authError.code.rawValue == 1000 {
                    print("⚠️ [AUTH] Sign in with Apple not available in simulator. Use 'Try Demo' button instead.")
                    errorMessage = "Sign in with Apple isn't available in the Simulator. Use a real device or tap Try Demo below."
                    return
                }
                if nsError.domain == "AKAuthenticationError" && nsError.code == -7026 {
                    print("⚠️ [AUTH] Authentication services not fully supported in simulator.")
                    errorMessage = "Sign in with Apple isn't available in the Simulator. Use a real device or tap Try Demo below."
                    return
                }
                #endif
                
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        // User cancelled - don't show error message
                        return
                    case .failed:
                        errorMessage = "Sign in failed. Please try again."
                    case .invalidResponse:
                        errorMessage = "Invalid response. Please try again."
                    case .notHandled:
                        errorMessage = "Sign in not handled. Please try iCloud sign in."
                    case .unknown:
                        // In simulator, unknown errors are common - handle gracefully
                        #if targetEnvironment(simulator)
                        print("⚠️ [AUTH] Sign in with Apple error in simulator (expected): \(authError.localizedDescription)")
                        #else
                        // On real device, log detailed error information
                        print("❌ [APPLE SIGN IN] Unknown error occurred")
                        print("❌ [APPLE SIGN IN] Error description: \(authError.localizedDescription)")
                        let errorInfo = authError.errorUserInfo
                        if !errorInfo.isEmpty {
                            print("❌ [APPLE SIGN IN] Error userInfo: \(errorInfo)")
                        }
                        // Apple sometimes reports "not connected" when the device is online (VPN, captive portal, or server issue)
                        errorMessage = "Sign-in didn't complete. Try again, use a different network, or turn off VPN. If it keeps happening, use Sign in with Email."
                        #endif
                    case .notInteractive:
                        errorMessage = "Sign in requires user interaction."
                    case .matchedExcludedCredential:
                        errorMessage = "Matched excluded credential. Please try again."
                    case .credentialImport:
                        errorMessage = "Credential import error. Please try again."
                    case .credentialExport:
                        errorMessage = "Credential export error. Please try again."
                    case .deviceNotConfiguredForPasskeyCreation:
                        errorMessage = "Device not configured for passkey creation."
                    case .preferSignInWithApple:
                        // System prefers Sign in with Apple - this is already our primary method
                        // This case shouldn't normally occur since we're using Sign in with Apple
                        errorMessage = "Please use Sign in with Apple."
                    @unknown default:
                        #if targetEnvironment(simulator)
                        print("⚠️ [AUTH] Sign in error in simulator (expected): \(authError.localizedDescription)")
                        #else
                        errorMessage = "Sign in error: \(authError.localizedDescription)"
                        #endif
                    }
                } else {
                    #if targetEnvironment(simulator)
                    let nsError = error as NSError
                    // Silently ignore common simulator authentication errors
                    if nsError.domain == "AKAuthenticationError" || nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" {
                        print("⚠️ [AUTH] Authentication error in simulator (expected): \(nsError.domain) Code=\(nsError.code)")
                        return
                    }
                    #endif
                    errorMessage = "Sign in error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Programmatic Sign in with Apple (used by custom-styled button so design matches other login buttons).
    /// Work is deferred so performRequests() runs in a separate run-loop pass, avoiding priority inversion (user-interactive waiting on default).
    private func performAppleSignIn() {
        print("🔍 [APPLE SIGN IN] Button tapped, requesting authorization...")
        DispatchQueue.global(qos: .default).async { [self] in
            let nonce = randomNonceString()
            let hashedNonce = sha256(nonce)
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.nonce = hashedNonce
            request.requestedScopes = [.fullName, .email]
            DispatchQueue.main.async(qos: .default) {
                let coordinator = AppleSignInCoordinator { [self] result in
                    DispatchQueue.main.async {
                        self.handleAppleSignIn(result: result)
                        self.appleSignInCoordinator = nil
                    }
                }
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = coordinator
                controller.presentationContextProvider = coordinator
                coordinator.cachedPresentationAnchor = Self.resolvePresentationAnchor()
                currentNonce = nonce
                appleSignInCoordinator = coordinator
                // Defer to next run loop so main thread is not in user-interactive context when ASAuthorizationController runs (avoids hang risk diagnostic).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, qos: .default) {
                    controller.performRequests()
                }
            }
        }
    }
    
    private static func resolvePresentationAnchor() -> ASPresentationAnchor {
        #if os(iOS)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            return window
        }
        if let anyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return anyWindow
        }
        fatalError("Faith Journal: No window available for Sign in with Apple. Please ensure the app is in the foreground.")
        #elseif os(macOS)
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            return window
        }
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSApplication.shared.windows.first {
            return window
        }
        fatalError("Faith Journal: No window available for Sign in with Apple. Please ensure the app window is open.")
        #else
        fatalError("Unsupported platform")
        #endif
    }
    
    private func signInToFirebaseWithApple(appleIDCredential: ASAuthorizationAppleIDCredential, nonce explicitNonce: String? = nil) async {
        print("🔍 [FIREBASE AUTH] Starting Firebase Auth sign-in with Apple...")
        
        #if canImport(FirebaseAuth)
        // Verify Firebase is configured before attempting sign-in
        guard FirebaseInitializer.shared.isConfigured else {
            print("❌ [FIREBASE AUTH] Firebase is not configured")
            print("❌ [FIREBASE AUTH] GoogleService-Info.plist is missing or Firebase not initialized")
            await MainActor.run {
                errorMessage = "Firebase not configured. Please check app setup."
                isAuthenticating = false
            }
            return
        }

        let nonce: String?
        if let explicit = explicitNonce, !explicit.isEmpty {
            nonce = explicit
        } else {
            nonce = await MainActor.run { currentNonce }
        }
        guard let nonce = nonce, !nonce.isEmpty else {
            print("❌ [FIREBASE AUTH] Missing nonce. Apple request did not include nonce.")
            await MainActor.run {
                errorMessage = "Sign in failed. Please try again."
                isAuthenticating = false
            }
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            print("❌ [FIREBASE AUTH] Failed to get identity token from Apple credential")
            await MainActor.run {
                errorMessage = "Failed to authenticate. Please try again."
                isAuthenticating = false
            }
            return
        }
        
        do {
            // Verify Firebase Auth instance is available
            let auth = Auth.auth()
            print("✅ [FIREBASE AUTH] Auth instance available")
            
            // Check current user state
            if let currentUser = auth.currentUser {
                print("ℹ️ [FIREBASE AUTH] Already signed in as: \(currentUser.uid)")
                print("ℹ️ [FIREBASE AUTH] Signing out previous user...")
                try? auth.signOut()
            }
            
            // Create Firebase credential from Apple credential (use official Apple API per Firebase docs)
            print("🔍 [FIREBASE AUTH] Creating OAuth credential with Apple ID token...")
            print("🔍 [FIREBASE AUTH] ID Token length: \(idTokenString.count) characters")
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            print("✅ [FIREBASE AUTH] OAuth credential created")
            print("🔍 [FIREBASE AUTH] Attempting Firebase Auth sign-in...")
            
            // Sign in to Firebase Auth with Apple credential
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUserId = authResult.user.uid
            
            print("✅ [FIREBASE AUTH] Signed in to Firebase successfully")
            print("✅ [FIREBASE AUTH] Firebase User ID: \(firebaseUserId)")
            print("✅ [FIREBASE AUTH] Same Apple ID will use same Firebase User ID across all devices")
            print("✅ [FIREBASE AUTH] Cross-device sync enabled")
            
            // Verify local user service authentication
            await userService.checkAuthentication()
            
            // Restart Firebase sync listener to enable cross-device sync
            // The listener will start automatically when AppRootView configures the service
            // But we also restart it here to ensure it picks up the new authenticated user immediately
            await MainActor.run {
                // Ensure sync service is configured (modelContext might already be set from AppRootView)
                // If not set yet, it will be set when AppRootView appears
                FirebaseSyncService.shared.restartListening()
                print("✅ [FIREBASE] Restarted sync listener after sign-in")
                print("✅ [FIREBASE] User ID: \(firebaseUserId)")
                print("✅ [FIREBASE] Cross-device sync is now active")
                print("✅ [FIREBASE] All journal entries will sync automatically across devices")
                
                // Test Firebase connection immediately after sign-in
                Task {
                    await FirebaseSyncService.shared.testFirebaseConnection()
                    
                    // After successful test, sync all existing data
                    // This ensures all local journal entries are uploaded to Firebase
                    print("🔄 [FIREBASE] Syncing all existing data to Firebase...")
                    #if canImport(FirebaseFirestore)
                    await FirebaseSyncService.shared.syncAllData()
                    #endif
                    print("✅ [FIREBASE] All existing data synced to Firebase")
                }
            }
            
            // Save Apple name to Firestore and search index (Apple only provides name on FIRST sign-in)
            #if canImport(FirebaseFirestore)
            if let fullName = appleIDCredential.fullName {
                let given = fullName.givenName ?? ""
                let family = fullName.familyName ?? ""
                let displayName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                if !displayName.isEmpty {
                    do {
                        try await Firestore.firestore().collection("users").document(firebaseUserId).setData([
                            "name": displayName,
                            "nameLower": displayName.lowercased(),
                            "updatedAt": Timestamp(date: Date())
                        ], merge: true)
                        FirebaseSyncService.shared.upsertUserSearchProfile(userId: firebaseUserId, displayName: displayName)
                        print("✅ [FAITH FRIENDS] Saved Apple name to search index: \(displayName)")
                    } catch {
                        print("⚠️ [FAITH FRIENDS] Could not save Apple name: \(error.localizedDescription)")
                    }
                }
            }
            #endif
            
            await MainActor.run {
                hasLoggedIn = true
                hasPreviouslyLoggedIn = true
                isAuthenticating = false
                dismiss()
            }
            
        } catch {
            print("❌ [FIREBASE AUTH] Sign in failed: \(error.localizedDescription)")
            print("❌ [FIREBASE AUTH] Error: \(error)")
            print("❌ [FIREBASE AUTH] Error type: \(type(of: error))")
            
            let nsError = error as NSError
            print("❌ [FIREBASE AUTH] Error domain: \(nsError.domain)")
            print("❌ [FIREBASE AUTH] Error code: \(nsError.code)")
            print("❌ [FIREBASE AUTH] Error userInfo: \(nsError.userInfo)")
            print("❌ [FIREBASE AUTH] Error localizedDescription: \(nsError.localizedDescription)")
            print("❌ [FIREBASE AUTH] Error localizedFailureReason: \(nsError.localizedFailureReason ?? "none")")
                
            // Check for common Firebase Auth errors
            if let authErrorCode = AuthErrorCode.Code(rawValue: nsError.code) {
                print("❌ [FIREBASE AUTH] AuthErrorCode: \(authErrorCode)")
                switch authErrorCode {
                case .networkError:
                    // Firebase often returns networkError even when device is online (VPN, firewall, App Check, captive portal)
                    if let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) {
                        print("❌ [FIREBASE AUTH] networkError underlying: code=\(underlying.code) domain=\(underlying.domain) \(underlying.localizedDescription)")
                    }
                    errorMessage = "Sign-in couldn't reach the server. Try again, or use a different network or turn off VPN. If you're on Wi‑Fi, try cellular (or vice versa)."
                case .invalidCredential:
                    errorMessage = "Invalid credentials. Please try signing in again."
                case .userDisabled:
                    errorMessage = "This account has been disabled. Please contact support."
                case .operationNotAllowed:
                    errorMessage = "Sign in with Apple is not enabled. In Firebase Console go to Authentication → Sign-in method and enable Apple."
                case .invalidAPIKey:
                    errorMessage = "Firebase configuration error. Please contact support."
                case .appNotAuthorized:
                    errorMessage = "App not authorized for Firebase Auth. Check Firebase Console and ensure the app’s bundle ID is allowed for Apple sign-in."
                case .accountExistsWithDifferentCredential:
                    errorMessage = "This Apple ID is not linked to your account. Use \"Sign in with Email\" with your account email instead, or use the same Apple ID you used when you first created the account."
                default:
                    if nsError.code == 17995 {
                        errorMessage = "Keychain access failed. If using Simulator, try \"Try Demo\" or restart the Simulator. On a real device, try again."
                    } else if nsError.code == 17999 {
                    #if targetEnvironment(simulator)
                    errorMessage = "Sign in with Apple isn't available in the Simulator. Use a real device or tap Try Demo below."
                    #else
                    if let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) {
                        errorMessage = "Sign in with Apple failed (17999). Real error: code=\(underlying.code) domain=\(underlying.domain). If this persists: turn off App Check for Auth in Firebase, check Service ID return URL and Key ID."
                    } else {
                        errorMessage = "Sign in with Apple failed (17999). Run from Xcode with iPhone connected and check console for \"17999 underlying\" to see the exact error."
                    }
                    #endif
                        print("❌ [FIREBASE AUTH] 17999 full userInfo: \(nsError.userInfo)")
                        if let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) {
                            print("❌ [FIREBASE AUTH] 17999 underlying: code=\(underlying.code) domain=\(underlying.domain) \(underlying.localizedDescription)")
                            print("❌ [FIREBASE AUTH] 17999 underlying userInfo: \(underlying.userInfo)")
                        }
                    } else {
                        errorMessage = "Sign in failed (Error \(nsError.code)). Please try again or use Sign in with Email."
                    }
                }
            } else if nsError.domain == "FIRAuthErrorDomain" {
                if nsError.code == 17999 {
                    #if targetEnvironment(simulator)
                    errorMessage = "Sign in with Apple isn't available in the Simulator. Use a real device or tap Try Demo below."
                    #else
                    if let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) {
                        errorMessage = "Sign in with Apple failed (17999). Real error: code=\(underlying.code) domain=\(underlying.domain). If this persists: turn off App Check for Auth in Firebase, check Service ID return URL and Key ID."
                    } else {
                        errorMessage = "Sign in with Apple failed (17999). Run from Xcode with iPhone connected and check console for \"17999 underlying\" to see the exact error."
                    }
                    #endif
                    print("❌ [FIREBASE AUTH] 17999 full userInfo: \(nsError.userInfo)")
                    if let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) {
                        print("❌ [FIREBASE AUTH] 17999 underlying: code=\(underlying.code) domain=\(underlying.domain) \(underlying.localizedDescription)")
                        print("❌ [FIREBASE AUTH] 17999 underlying userInfo: \(underlying.userInfo)")
                    }
                } else {
                    errorMessage = "Authentication error (Code \(nsError.code)). Please try again."
                }
            } else if nsError.domain == NSURLErrorDomain && (nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == -1009) {
                // System reports "The Internet connection appears to be offline" even when connected (VPN, captive portal, DNS)
                errorMessage = "Sign-in couldn't reach the server. Try again, use a different network, or turn off VPN. If you're on Wi‑Fi, try cellular (or vice versa)."
            } else {
                errorMessage = "Failed to connect to sync service. Error: \(nsError.localizedDescription)"
            }
            
            await MainActor.run {
                self.errorMessage = errorMessage
                isAuthenticating = false
            }
        }
        #else
        // Firebase Auth not available - fallback to local authentication
        print("⚠️ [FIREBASE AUTH] Firebase Auth not available - using local authentication")
        await userService.checkAuthentication()
        
        if userService.isAuthenticated {
            await MainActor.run {
                hasLoggedIn = true
                hasPreviouslyLoggedIn = true
                isAuthenticating = false
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = "Authentication failed. Please try again."
                isAuthenticating = false
            }
        }
        #endif
    }

    // MARK: - Nonce helpers (Firebase Auth + Apple)

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if status != errSecSuccess {
                // Extremely unlikely; fall back to UUID-based entropy.
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }

            randomBytes.forEach { byte in
                if remainingLength == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
    
    
    private func handleFaceIDLogin() {
        authenticateWithBiometrics(reason: "Sign in to Faith Journal with Face ID")
    }
    
    private func handleTouchIDLogin() {
        authenticateWithBiometrics(reason: "Sign in to Faith Journal with Touch ID")
    }
    
    private func authenticateWithBiometrics(reason: String) {
        isAuthenticating = true
        errorMessage = nil
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                errorMessage = "Biometric authentication not available: \(error.localizedDescription)"
            } else {
                errorMessage = "Biometric authentication not available on this device."
            }
            isAuthenticating = false
            return
        }
        
        let reasonCopy = reason
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonCopy) { success, authenticationError in
            // LAContext calls this on an arbitrary queue; never touch SwiftUI from here.
            // Schedule all UI work on main, then run async success path from main.
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    Task { @MainActor in
                        await verifyiCloudAfterBiometric()
                    }
                } else {
                    if let authError = authenticationError as? LAError {
                        switch authError.code {
                        case .userCancel:
                            errorMessage = "Authentication cancelled."
                        case .userFallback:
                            errorMessage = "Please use Sign in with Apple or Email instead."
                        case .biometryNotAvailable:
                            errorMessage = "Biometric authentication not available."
                        case .biometryNotEnrolled:
                            errorMessage = "No biometric data enrolled. Please set up Face ID or Touch ID in Settings."
                        case .biometryLockout:
                            errorMessage = "Biometric authentication locked. Please use Sign in with Apple or Email."
                        default:
                            errorMessage = "Biometric authentication failed: \(authError.localizedDescription)"
                        }
                    } else if let err = authenticationError {
                        errorMessage = "Biometric authentication failed: \(err.localizedDescription)"
                    } else {
                        errorMessage = "Biometric authentication failed."
                    }
                }
            }
        }
    }
    
    @MainActor
    private func verifyiCloudAfterBiometric() async {
        print("🔍 [FACE ID] Verifying authentication after Face ID...")
        await userService.checkAuthentication()
        #if canImport(FirebaseAuth)
        let configured = FirebaseInitializer.shared.isConfigured
        let currentUser = configured ? Auth.auth().currentUser : nil
        let hasFirebaseUser = currentUser != nil
        if hasFirebaseUser {
            print("✅ [FACE ID] Firebase session found - signing in with existing account")
            hasLoggedIn = true
            hasPreviouslyLoggedIn = true
            DispatchQueue.main.async { dismiss() }
        } else if userService.isAuthenticated {
            print("⚠️ [FACE ID] No Firebase account. Use Sign in with Apple or Email first.")
            errorMessage = "Use Sign in with Apple or Email to sign in to your account. Face ID can then unlock the app next time."
        } else {
            errorMessage = "Authentication failed. Please try again."
        }
        #else
        if userService.isAuthenticated {
            hasLoggedIn = true
            hasPreviouslyLoggedIn = true
            DispatchQueue.main.async { dismiss() }
        } else {
            errorMessage = "Authentication failed. Please try again."
        }
        #endif
    }
    
    // MARK: - Email/Password Authentication
    
    private var emailPasswordAuthView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: {
                    withAnimation {
                        showEmailPasswordAuth = false
                        email = ""
                        password = ""
                        confirmPassword = ""
                        username = ""
                        isSignUpMode = false
                        errorMessage = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        #if os(macOS)
                        .foregroundColor(.primary)
                        #else
                        .foregroundColor(.white)
                        #endif
                        .font(.headline)
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Return to Sign in with Apple and Email options")
                
                Spacer()
                
                Text(isSignUpMode ? "Create Account" : "Sign In")
                    .font(.headline)
                    .font(.body.weight(.bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    }
                }) {
                    Text(isSignUpMode ? "Sign In" : "Sign Up")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        #if os(macOS)
                        .foregroundColor(.primary)
                        #else
                        .foregroundColor(.white)
                        #endif
                }
                .accessibilityLabel(isSignUpMode ? "Switch to Sign In" : "Switch to Sign Up")
            }
            .padding(.horizontal)
            
            // Username field (for sign up)
            if isSignUpMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    TextField("Enter your name", text: $username)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }
            }
            
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            
            // Confirm password (for sign up)
            if isSignUpMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
            }
            
            // Sign in/Sign up button
            Button(action: {
                if isSignUpMode {
                    handleSignUp()
                } else {
                    handleEmailSignIn()
                }
            }) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUpMode ? "Create Account" : "Sign In")
                            .font(.headline)
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .disabled(isAuthenticating || email.isEmpty || password.isEmpty || (isSignUpMode && (confirmPassword.isEmpty || username.isEmpty)))
            .accessibilityLabel(isSignUpMode ? "Create Account" : "Sign In with Email")
            
            // Forgot password (sign in only)
            if !isSignUpMode {
                Button(action: {
                    showPasswordResetAlert = true
                }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .accessibilityLabel("Forgot Password")
                .accessibilityHint("Send a password reset link to your email")
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .alert("Reset Password", isPresented: $showPasswordResetAlert) {
            TextField("Enter your email", text: $email)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
            Button("Cancel", role: .cancel) {
                email = ""
            }
            Button("Send Reset Email") {
                handlePasswordReset()
            }
        } message: {
            Text("Enter your email address and we'll send you a link to reset your password.")
        }
        .alert("Password Reset Email Sent", isPresented: $showPasswordResetSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We've sent a password reset link to \(email). Please check your email and follow the instructions to reset your password.")
        }
    }
    
    private func handleEmailSignIn() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            await signInWithEmail(email: email, password: password)
        }
    }
    
    private func handleSignUp() {
        guard !email.isEmpty && !password.isEmpty && !username.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            await signUpWithEmail(email: email, password: password, username: username)
        }
    }
    
    private func handlePasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        // Validate email format
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            #if canImport(FirebaseAuth)
            guard FirebaseInitializer.shared.isConfigured else {
                await MainActor.run {
                    errorMessage = "Firebase not configured. Please check app setup."
                    isAuthenticating = false
                }
                return
            }
            
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                await MainActor.run {
                    errorMessage = nil
                    isAuthenticating = false
                    showPasswordResetAlert = false
                    showPasswordResetSent = true
                }
                print("✅ [FIREBASE AUTH] Password reset email sent to: \(email)")
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    let authError = error as NSError
                    switch authError.code {
                    case 17011: // User not found
                        errorMessage = "No account found with this email address"
                    case 17008: // Invalid email
                        errorMessage = "Invalid email address"
                    case 17020: // Network error
                        errorMessage = "Network error. Please check your connection"
                    default:
                        errorMessage = "Failed to send reset email: \(error.localizedDescription)"
                    }
                }
                print("❌ [FIREBASE AUTH] Password reset failed: \(error.localizedDescription)")
            }
            #else
            await MainActor.run {
                errorMessage = "Firebase Auth packages not linked. Please rebuild the app after linking Firebase packages in Xcode."
                isAuthenticating = false
            }
            print("❌ [FIREBASE AUTH] FirebaseAuth cannot be imported at compile time")
            print("❌ [FIREBASE AUTH] This means Firebase packages are not properly linked")
            print("❌ [FIREBASE AUTH] Solution: Link packages in Xcode → Clean build (⇧⌘K) → Rebuild (⌘B)")
            #endif
        }
    }
    
    private func signInWithEmail(email: String, password: String) async {
        print("🔍 [FIREBASE AUTH] Starting email/password sign-in...")
        
        #if canImport(FirebaseAuth)
        // Defensive: initialize Firebase if needed (LoginView can appear before app init completes).
        ensureFirebaseInitialized()
        guard FirebaseInitializer.shared.isConfigured else {
            print("❌ [FIREBASE AUTH] Firebase is not configured")
            await MainActor.run {
                errorMessage = "Firebase not configured. Please check app setup."
                isAuthenticating = false
            }
            return
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let firebaseUserId = authResult.user.uid
            
            print("✅ [FIREBASE AUTH] Signed in with email successfully")
            print("✅ [FIREBASE AUTH] Firebase User ID: \(firebaseUserId)")
            print("✅ [FIREBASE AUTH] Email: \(email)")
            
            // Update user profile with email if available
            if let userEmail = authResult.user.email {
                print("✅ [FIREBASE AUTH] User email: \(userEmail)")
            }
            
            // Restart Firebase sync listener
            await MainActor.run {
                FirebaseSyncService.shared.restartListening()
                print("✅ [FIREBASE] Restarted sync listener after email sign-in")
                print("✅ [FIREBASE] User ID: \(firebaseUserId)")
                print("✅ [FIREBASE] Cross-device sync is now active")
                
                // Test Firebase connection and sync existing data
                Task {
                    await FirebaseSyncService.shared.testFirebaseConnection()
                    print("🔄 [FIREBASE] Syncing all existing data to Firebase...")
                    #if canImport(FirebaseFirestore)
                    await FirebaseSyncService.shared.syncAllData()
                    #endif
                    print("✅ [FIREBASE] All existing data synced to Firebase")
                }
            }
            
            await MainActor.run {
                hasLoggedIn = true
                hasPreviouslyLoggedIn = true
                isAuthenticating = false
                dismiss()
            }
            
        } catch {
            print("❌ [FIREBASE AUTH] Email sign-in failed: \(error.localizedDescription)")
            await MainActor.run {
                let nsError = error as NSError
                let code = AuthErrorCode(_nsError: nsError)
                print("❌ [FIREBASE AUTH] Sign-in error code: \(code.code.rawValue) (\(code.code))")
                
                switch code.code {
                case .invalidEmail:
                    errorMessage = "Invalid email address."
                case .wrongPassword:
                    errorMessage = "Incorrect password."
                case .userNotFound:
                    errorMessage = "No account found with this email. Sign up, or use the email you used when you first created your account."
                case .userDisabled:
                    errorMessage = "This account has been disabled."
                case .networkError:
                    errorMessage = "Network error. Please check your connection."
                case .tooManyRequests:
                    errorMessage = "Too many attempts. Try again in a few minutes."
                case .operationNotAllowed:
                    errorMessage = "Email/password sign-in is not enabled for this app. Enable it in Firebase Console → Authentication → Sign-in method."
                case .invalidCredential:
                    errorMessage = "Incorrect email or password, or no account with this email. Use the email you signed up with, or create an account."
                case .accountExistsWithDifferentCredential:
                    errorMessage = "This email is already linked to a different sign-in method. Try Sign in with Apple."
                default:
                    // Keychain error (17995) - common in Simulator
                    if nsError.code == 17995 {
                        errorMessage = "Keychain access failed. If using Simulator, try \"Try Demo\" or restart the Simulator. On a real device, try again."
                    } else {
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                    }
                }
                isAuthenticating = false
            }
        }
        #else
        await MainActor.run {
            errorMessage = "Firebase Auth packages not linked. Please rebuild the app after linking Firebase packages in Xcode."
            isAuthenticating = false
        }
        print("❌ [FIREBASE AUTH] FirebaseAuth cannot be imported at compile time")
        print("❌ [FIREBASE AUTH] Solution: Link packages in Xcode → Clean build (⇧⌘K) → Rebuild (⌘B)")
        #endif
    }
    
    private func signUpWithEmail(email: String, password: String, username: String) async {
        print("🔍 [FIREBASE AUTH] Starting email/password sign-up...")
        
        #if canImport(FirebaseAuth)
        // Defensive: initialize Firebase if needed.
        ensureFirebaseInitialized()
        guard FirebaseInitializer.shared.isConfigured else {
            print("❌ [FIREBASE AUTH] Firebase is not configured")
            await MainActor.run {
                errorMessage = "Firebase not configured. Please check app setup."
                isAuthenticating = false
            }
            return
        }
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let firebaseUserId = authResult.user.uid
            
            print("✅ [FIREBASE AUTH] Account created successfully")
            print("✅ [FIREBASE AUTH] Firebase User ID: \(firebaseUserId)")
            print("✅ [FIREBASE AUTH] Email: \(email)")
            
            // Update user profile with username and email
            // The UserProfile will be created/updated when the app loads
            // For now, we'll store it in UserDefaults temporarily
            UserDefaults.standard.set(username, forKey: "pendingUsername")
            UserDefaults.standard.set(email, forKey: "pendingEmail")
            
            // Send email verification (optional but recommended)
            try? await authResult.user.sendEmailVerification()
            print("✅ [FIREBASE AUTH] Verification email sent")
            
            // Restart Firebase sync listener
            await MainActor.run {
                FirebaseSyncService.shared.restartListening()
                print("✅ [FIREBASE] Restarted sync listener after sign-up")
                print("✅ [FIREBASE] User ID: \(firebaseUserId)")
                print("✅ [FIREBASE] Cross-device sync is now active")
                
                // Test Firebase connection and sync existing data
                Task {
                    await FirebaseSyncService.shared.testFirebaseConnection()
                    print("🔄 [FIREBASE] Syncing all existing data to Firebase...")
                    #if canImport(FirebaseFirestore)
                    await FirebaseSyncService.shared.syncAllData()
                    #endif
                    print("✅ [FIREBASE] All existing data synced to Firebase")
                }
            }
            
            await MainActor.run {
                hasLoggedIn = true
                hasPreviouslyLoggedIn = true
                isAuthenticating = false
                dismiss()
            }
            
        } catch {
            print("❌ [FIREBASE AUTH] Sign-up failed: \(error.localizedDescription)")
            await MainActor.run {
                let nsError = error as NSError
                let code = AuthErrorCode(_nsError: nsError)
                print("❌ [FIREBASE AUTH] Sign-up error code: \(code.code.rawValue) (\(code.code))")
                
                switch code.code {
                case .emailAlreadyInUse:
                    errorMessage = "An account with this email already exists. Please sign in instead."
                case .invalidEmail:
                    errorMessage = "Invalid email address."
                case .weakPassword:
                    errorMessage = "Password is too weak. Please use a stronger password."
                case .networkError:
                    errorMessage = "Network error. Please check your connection."
                case .operationNotAllowed:
                    errorMessage = "Email/password sign-up is not enabled for this app. Enable it in Firebase Console → Authentication → Sign-in method."
                default:
                    if nsError.code == 17995 {
                        errorMessage = "Keychain access failed. If using Simulator, try \"Try Demo\" or restart the Simulator. On a real device, try again."
                    } else {
                        errorMessage = "Sign up failed: \(error.localizedDescription)"
                    }
                }
                isAuthenticating = false
            }
        }
        #else
        await MainActor.run {
            errorMessage = "Firebase Auth packages not linked. Please rebuild the app after linking Firebase packages in Xcode."
            isAuthenticating = false
        }
        print("❌ [FIREBASE AUTH] FirebaseAuth cannot be imported at compile time")
        print("❌ [FIREBASE AUTH] Solution: Link packages in Xcode → Clean build (⇧⌘K) → Rebuild (⌘B)")
        #endif
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
            )
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Programmatic Sign in with Apple (same design as other login buttons)
@available(iOS 17.0, macOS 14.0, *)
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    /// Set on main before performRequests() so presentationAnchor can return without touching UIKit/AppKit from background (avoids priority inversion).
    var cachedPresentationAnchor: ASPresentationAnchor?
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let cached = cachedPresentationAnchor { return cached }
        #if os(iOS)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            return window
        }
        if let anyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return anyWindow
        }
        fatalError("Faith Journal: No window available for Sign in with Apple.")
        #elseif os(macOS)
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSApplication.shared.windows.first {
            return window
        }
        fatalError("Faith Journal: No window available for Sign in with Apple.")
        #else
        fatalError("Unsupported platform")
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview {
    LoginView()
}

