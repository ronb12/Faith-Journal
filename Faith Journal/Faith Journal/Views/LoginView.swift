import SwiftUI
import LocalAuthentication
import AuthenticationServices

// Try to import Firebase - if it fails, we'll handle it at runtime
#if canImport(FirebaseAuth)
import FirebaseAuth
#else
// Package is linked but compiler can't find it - will check at runtime
#endif

@available(iOS 17.0, *)
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
    
    init(hasLoggedIn: Binding<Bool> = .constant(false)) {
        _hasLoggedIn = hasLoggedIn
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient Background matching landing page
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.8),
                        Color.blue.opacity(0.9),
                        Color.purple.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
                            
                            // Show biometric first if previously logged in
                            if hasPreviouslyLoggedIn && biometricType != .none {
                                biometricButton
                                    .disabled(isAuthenticating)
                                
                                Divider()
                                    .background(Color.white.opacity(0.3))
                            }
                            
                            // Email/Password Authentication Section
                            if showEmailPasswordAuth {
                                // Always show the form - let FirebaseInitializer handle availability
                                // The form will show appropriate errors if Firebase isn't available
                                emailPasswordAuthView
                            } else {
                                // Sign in with Apple Button (primary authentication method)
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        print("🔍 [APPLE SIGN IN] Button tapped, requesting authorization...")
                                        request.requestedScopes = [.fullName, .email]
                                        print("✅ [APPLE SIGN IN] Request configured with scopes: fullName, email")
                                    },
                                    onCompletion: { result in
                                        print("🔍 [APPLE SIGN IN] Authorization completed")
                                        print("🔍 [APPLE SIGN IN] Result: \(result)")
                                        handleAppleSignIn(result: result)
                                    }
                                )
                                .signInWithAppleButtonStyle(.white)
                                .frame(height: 50)
                                .disabled(isAuthenticating)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                
                                // Toggle to email/password
                                Button(action: {
                                    withAnimation {
                                        showEmailPasswordAuth = true
                                    }
                                }) {
                                    Text("Sign in with Email")
                                        .font(.headline)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
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
                            }
                            
                            // Show biometric as alternative if not shown above
                            if !hasPreviouslyLoggedIn && biometricType != .none {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                
                                biometricButton
                                    .disabled(isAuthenticating)
                            }
                            
                            // Demo button for testing
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
                                    
                                    // Now sync existing data
                                    print("🔄 [DEMO] Syncing existing data to Firebase...")
                                    await FirebaseSyncService.shared.syncAllData()
                                    
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
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
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
                        }
                        .padding(28)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.ultraThinMaterial)
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
                
                Task {
                    // Sign in to Firebase Auth with Apple credential for cross-device sync
                    await signInToFirebaseWithApple(appleIDCredential: appleIDCredential)
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
            print("❌ [APPLE SIGN IN] Sign in failed")
            print("❌ [APPLE SIGN IN] Error: \(error)")
            print("❌ [APPLE SIGN IN] Error localized: \(error.localizedDescription)")
            
            Task { @MainActor in
                isAuthenticating = false
                
                let nsError = error as NSError
                print("❌ [APPLE SIGN IN] Error domain: \(nsError.domain)")
                print("❌ [APPLE SIGN IN] Error code: \(nsError.code)")
                print("❌ [APPLE SIGN IN] Error userInfo: \(nsError.userInfo)")
                
                // Note: Sign in with Apple works in simulator when capability is added
                
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
                        // Log detailed error information
                        print("❌ [APPLE SIGN IN] Unknown error occurred")
                        print("❌ [APPLE SIGN IN] Error description: \(authError.localizedDescription)")
                        let errorInfo = authError.errorUserInfo
                        if !errorInfo.isEmpty {
                            print("❌ [APPLE SIGN IN] Error userInfo: \(errorInfo)")
                        }
                        // Check if this is a Firebase configuration issue
                        errorMessage = "Sign in failed. Please check your internet connection and try again."
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
                        errorMessage = "Sign in error: \(authError.localizedDescription)"
                    }
                } else {
                    errorMessage = "Sign in error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func signInToFirebaseWithApple(appleIDCredential: ASAuthorizationAppleIDCredential) async {
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
            
            // Create Firebase credential from Apple credential
            print("🔍 [FIREBASE AUTH] Creating OAuth credential with Apple ID token...")
            print("🔍 [FIREBASE AUTH] ID Token length: \(idTokenString.count) characters")
            
            // Create Firebase credential from Apple credential
            // For Apple Sign In with Firebase, providerID must be "apple.com"
            // rawNonce can be empty string if not using nonce, accessToken is optional
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nil,
                accessToken: nil
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
                    await FirebaseSyncService.shared.syncAllData()
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
                    errorMessage = "Network error. Please check your internet connection and try again."
                case .invalidCredential:
                    errorMessage = "Invalid credentials. Please try signing in again."
                case .userDisabled:
                    errorMessage = "This account has been disabled. Please contact support."
                case .operationNotAllowed:
                    errorMessage = "Sign in with Apple is not enabled in Firebase. Please check Firebase Console settings."
                case .invalidAPIKey:
                    errorMessage = "Firebase configuration error. Please contact support."
                case .appNotAuthorized:
                    errorMessage = "App not authorized for Firebase Auth. Please check Firebase Console settings."
                default:
                    errorMessage = "Sign in failed (Error \(nsError.code)). Please try again or contact support."
                }
            } else if nsError.domain == "FIRAuthErrorDomain" {
                // Firebase Auth error but not in AuthErrorCode enum
                errorMessage = "Authentication error (Code \(nsError.code)). Please try again."
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
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Task { @MainActor in
                if let error = error {
                    errorMessage = "Biometric authentication not available: \(error.localizedDescription)"
                } else {
                    errorMessage = "Biometric authentication not available on this device."
                }
                isAuthenticating = false
            }
            return
        }
        
        // Perform biometric authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            Task { @MainActor in
                isAuthenticating = false
                
                if success {
                    // Biometric authentication successful
                    // Now verify iCloud authentication
                    Task {
                        await verifyiCloudAfterBiometric()
                    }
                } else {
                    // Biometric authentication failed
                    if let authError = authenticationError {
                        switch authError {
                        case LAError.userCancel:
                            errorMessage = "Authentication cancelled."
                        case LAError.userFallback:
                            errorMessage = "Please use iCloud sign in instead."
                        case LAError.biometryNotAvailable:
                            errorMessage = "Biometric authentication not available."
                        case LAError.biometryNotEnrolled:
                            errorMessage = "No biometric data enrolled. Please set up Face ID or Touch ID in Settings."
                        case LAError.biometryLockout:
                            errorMessage = "Biometric authentication locked. Please use iCloud sign in."
                        default:
                            errorMessage = "Biometric authentication failed: \(authError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Biometric authentication failed."
                    }
                }
            }
        }
    }
    
    private func verifyiCloudAfterBiometric() async {
        // After successful biometric authentication, verify user
        print("🔍 [FACE ID] Verifying authentication after Face ID...")
        
        // CloudKit removed - using Firebase for sync
        await userService.checkAuthentication()
        
        if userService.isAuthenticated {
            print("✅ [FACE ID] Authentication verified - Firebase sync enabled")
            await MainActor.run {
                hasLoggedIn = true
                hasPreviouslyLoggedIn = true
                dismiss()
            }
        } else {
            print("⚠️ [FACE ID] Authentication failed")
            await MainActor.run {
                errorMessage = "Authentication failed. Please try again."
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    private var emailPasswordAuthView: some View {
        VStack(spacing: 20) {
            // Error message display
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
                        .foregroundColor(.white)
                        .font(.headline)
                }
                
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
                        // Clear fields when switching modes
                        password = ""
                        confirmPassword = ""
                    }
                }) {
                    Text(isSignUpMode ? "Sign In" : "Sign Up")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.blue)
                }
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
                        .autocapitalization(.words)
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
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
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
            
            // Forgot password (sign in only)
            if !isSignUpMode {
                Button(action: {
                    showPasswordResetAlert = true
                }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .alert("Reset Password", isPresented: $showPasswordResetAlert) {
            TextField("Enter your email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
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
        // Clear any previous errors
        errorMessage = nil
        
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        
        // Validate email format
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Validate password length
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long"
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
                    await FirebaseSyncService.shared.syncAllData()
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
            print("❌ [FIREBASE AUTH] Error type: \(type(of: error))")
            let authError = error as NSError
            print("❌ [FIREBASE AUTH] Error domain: \(authError.domain)")
            print("❌ [FIREBASE AUTH] Error code: \(authError.code)")
            print("❌ [FIREBASE AUTH] Error userInfo: \(authError.userInfo)")
            
            await MainActor.run {
                // Check for Firebase Auth error codes
                if let authErrorCode = AuthErrorCode.Code(rawValue: authError.code) {
                    switch authErrorCode {
                    case .invalidEmail:
                        errorMessage = "Invalid email address. Please check your email format."
                    case .wrongPassword:
                        errorMessage = "Incorrect password. Please try again or use 'Forgot Password?'"
                    case .userNotFound:
                        errorMessage = "No account found with this email. Please sign up first."
                    case .networkError:
                        errorMessage = "Network error. Please check your internet connection and try again."
                    case .operationNotAllowed:
                        errorMessage = "Email/Password authentication is not enabled. Please contact support or use Sign in with Apple."
                        print("❌ [FIREBASE AUTH] Email/Password authentication may not be enabled in Firebase Console")
                    case .tooManyRequests:
                        errorMessage = "Too many failed attempts. Please wait a few minutes and try again."
                    case .userDisabled:
                        errorMessage = "This account has been disabled. Please contact support."
                    case .invalidCredential:
                        errorMessage = "Invalid email or password. Please check your credentials."
                    default:
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                        print("❌ [FIREBASE AUTH] Unknown error code: \(authError.code)")
                    }
                } else {
                    // Handle error codes that might not be in AuthErrorCode enum
                    switch authError.code {
                    case 17008: // Invalid email
                        errorMessage = "Invalid email address. Please check your email format."
                    case 17009: // Wrong password
                        errorMessage = "Incorrect password. Please try again or use 'Forgot Password?'"
                    case 17011: // User not found
                        errorMessage = "No account found with this email. Please sign up first."
                    case 17020: // Network error
                        errorMessage = "Network error. Please check your internet connection and try again."
                    case 17026: // Operation not allowed
                        errorMessage = "Email/Password authentication is not enabled in Firebase Console. Please enable it in Authentication → Sign-in method → Email/Password."
                        print("❌ [FIREBASE AUTH] Error 17026: Email/Password authentication not enabled")
                    default:
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                        print("❌ [FIREBASE AUTH] Unknown error code: \(authError.code), domain: \(authError.domain)")
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
                    await FirebaseSyncService.shared.syncAllData()
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
                let authError = error as NSError
                switch authError.code {
                case 17007: // Email already in use
                    errorMessage = "An account with this email already exists. Please sign in instead."
                case 17008: // Invalid email
                    errorMessage = "Invalid email address"
                case 17026: // Weak password
                    errorMessage = "Password is too weak. Please use a stronger password."
                case 17020: // Network error
                    errorMessage = "Network error. Please check your connection"
                default:
                    errorMessage = "Sign up failed: \(error.localizedDescription)"
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

@available(iOS 17.0, *)
#Preview {
    LoginView()
}

