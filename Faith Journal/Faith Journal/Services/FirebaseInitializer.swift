//
//  FirebaseInitializer.swift
//  Faith Journal
//
//  Firebase initialization and configuration
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@available(iOS 17.0, macOS 14.0, *)
class FirebaseInitializer {
    static let shared = FirebaseInitializer()
    
    private var isInitialized = false
    
    private init() {}
    
    /// Initialize Firebase
    func initialize() {
        print("🔍 [FIREBASE] Starting initialization...")
        print("🔍 [FIREBASE] Checking Firebase SDK availability...")
        
        #if canImport(FirebaseCore)
        print("✅ [FIREBASE] FirebaseCore can be imported")
        initializeFirebaseIfAvailable()
        #else
        print("❌ [FIREBASE] FirebaseCore CANNOT be imported")
        print("❌ [FIREBASE] Firebase packages are not properly linked in Xcode")
        print("❌ [FIREBASE] To fix this:")
        print("   1. Open Xcode")
        print("   2. Go to File → Add Package Dependencies...")
        print("   3. Enter: https://github.com/firebase/firebase-ios-sdk")
        print("   4. Select these products:")
        print("      - FirebaseCore")
        print("      - FirebaseFirestore")
        print("      - FirebaseAuth")
        print("   5. Click Add Package")
        print("   6. Ensure target membership is checked for all packages")
        #endif
    }
    
    /// Initialize Firebase if Firestore is available, otherwise handle unavailability
    private func initializeFirebaseIfAvailable() {
        #if canImport(FirebaseFirestore)
        initializeFirebaseWithFirestore()
        #else
        handleFirestoreUnavailable()
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    /// Initialize Firebase when Firestore is available
    private func initializeFirebaseWithFirestore() {
        // FirebaseFirestore is available - proceed with initialization
        print("✅ [FIREBASE] FirebaseFirestore can be imported")
        
        #if canImport(FirebaseAuth)
        print("✅ [FIREBASE] FirebaseAuth can be imported")
        #else
        print("⚠️ [FIREBASE] FirebaseAuth cannot be imported (Sign in with Apple may not work)")
        #endif
        
        guard !isInitialized else {
            print("ℹ️ [FIREBASE] Already initialized")
            return
        }
        
        // Check if GoogleService-Info.plist exists
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              FileManager.default.fileExists(atPath: path) else {
            print("❌ [FIREBASE] GoogleService-Info.plist not found in app bundle")
            print("❌ [FIREBASE] This is REQUIRED for Firebase Auth (Sign in with Apple)")
            print("❌ [FIREBASE] Please download from Firebase Console:")
            print("   1. Go to https://console.firebase.google.com/")
            print("   2. Select project: faith-journal-d2a32")
            print("   3. Click ⚙️ → Project settings")
            print("   4. Scroll to 'Your apps' → iOS app")
            print("   5. Download GoogleService-Info.plist")
            print("   6. Add to Xcode project (ensure target membership is checked)")
            print("❌ [FIREBASE] Firebase sync and Sign in with Apple will not work without this file")
            return
        }
        
        print("✅ [FIREBASE] GoogleService-Info.plist found at: \(path)")
        
        // Validate GoogleService-Info.plist has real values (not placeholders)
        if let plistData = NSDictionary(contentsOfFile: path) {
            let apiKey = plistData["API_KEY"] as? String ?? ""
            let projectId = plistData["PROJECT_ID"] as? String ?? ""
            let bundleId = plistData["BUNDLE_ID"] as? String ?? ""
            
            // Check for placeholder values
            if apiKey.contains("YOUR_API_KEY") || apiKey.isEmpty ||
               projectId.contains("your-project") || projectId.isEmpty ||
               bundleId.contains("yourcompany") || bundleId.isEmpty {
                print("❌ [FIREBASE] GoogleService-Info.plist contains placeholder values!")
                print("❌ [FIREBASE] API_KEY: \(apiKey.isEmpty ? "empty" : "\(apiKey.prefix(20))...")")
                print("❌ [FIREBASE] PROJECT_ID: \(projectId)")
                print("❌ [FIREBASE] BUNDLE_ID: \(bundleId)")
                print("❌ [FIREBASE] Please download the real GoogleService-Info.plist from Firebase Console")
                print("❌ [FIREBASE] Project: faith-journal-d2a32")
                print("❌ [FIREBASE] Firebase will NOT work with placeholder values")
                return
            }
            
            print("✅ [FIREBASE] GoogleService-Info.plist validated - contains real values")
            print("✅ [FIREBASE] PROJECT_ID: \(projectId)")
            print("✅ [FIREBASE] BUNDLE_ID: \(bundleId)")
        } else {
            print("⚠️ [FIREBASE] Could not read GoogleService-Info.plist contents")
        }
        
        // Configure Firebase App (FirebaseCore already checked at line 35)
        FirebaseApp.configure()
        
        // Reduce Firebase console noise (e.g. "10.29.0 - [FirebaseFirestore][I-FST000001] (null)")
        FirebaseConfiguration.shared.setLoggerLevel(.warning)
        
        // Log Firebase App configuration details
        if let app = FirebaseApp.app() {
            print("✅ [FIREBASE] Firebase App configured")
            print("✅ [FIREBASE] App name: \(app.name)")
            print("✅ [FIREBASE] Options: \(app.options.googleAppID)")
            print("✅ [FIREBASE] Project ID: \(app.options.projectID ?? "unknown")")
        } else {
            print("❌ [FIREBASE] Firebase App configuration failed")
        }
        
        // Configure Firestore settings BEFORE accessing Firestore
        // Settings must be set before any other Firestore methods are called
        let settings = FirestoreSettings()
        // Use new cacheSettings API (replaces deprecated isPersistenceEnabled and cacheSizeBytes)
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        
        // Get Firestore instance and set settings immediately
        let db = Firestore.firestore()
        db.settings = settings
        print("✅ [FIREBASE] Firestore persistence enabled")
        
        // Mark as initialized AFTER settings are configured
        isInitialized = true
        
        // Verify Firebase Auth is available
        #if canImport(FirebaseAuth)
        let auth = Auth.auth()
        print("✅ [FIREBASE] Firebase Auth available")
        if let currentUser = auth.currentUser {
            print("ℹ️ [FIREBASE] Current user: \(currentUser.uid)")
        } else {
            print("ℹ️ [FIREBASE] No current user signed in")
        }
        #endif
        
        print("✅ [FIREBASE] Firebase initialized successfully")
    }
    #endif
    
    /// Handle case when FirebaseFirestore is not available
    private func handleFirestoreUnavailable() {
        // FirebaseFirestore is NOT available
        print("❌ [FIREBASE] FirebaseFirestore CANNOT be imported")
        print("❌ [FIREBASE] Add FirebaseFirestore package to Xcode project")
    }
    
    /// Check if Firebase is properly configured
    var isConfigured: Bool {
        #if canImport(FirebaseCore)
        return isInitialized && FirebaseApp.app() != nil
        #else
        return false
        #endif
    }
    
    /// Check if Firebase Auth is available at runtime
    /// Uses both compile-time and runtime checks
    var isAuthAvailable: Bool {
        // First check compile-time availability
        #if canImport(FirebaseAuth)
        // If we can import at compile time, check if it's configured
        print("✅ [FIREBASE] FirebaseAuth can be imported at compile time")
        return isConfigured
        #else
        // If compile-time check fails, try runtime check using Objective-C runtime
        // This works even if packages are linked but not recognized at compile time
        print("⚠️ [FIREBASE] FirebaseAuth cannot be imported at compile time - trying runtime check")
        
        // Try to find the class at runtime
        if let authClass = NSClassFromString("FIRAuth") {
            print("✅ [FIREBASE] FirebaseAuth found via runtime check (FIRAuth class exists)")
            print("   Class: \(authClass)")
            // If class exists, check if Firebase is configured
            if isConfigured {
                print("✅ [FIREBASE] Firebase is configured - Auth should work")
                return true
            } else {
                print("⚠️ [FIREBASE] FirebaseAuth class exists but Firebase not configured")
                print("   Need to call FirebaseInitializer.shared.initialize() first")
                return false
            }
        } else {
            print("❌ [FIREBASE] FirebaseAuth not found (compile-time and runtime check failed)")
            print("❌ [FIREBASE] FIRAuth class not available at runtime")
            print("❌ [FIREBASE] This means packages are not linked to the target")
            print("❌ [FIREBASE] Solution: Add packages to 'Frameworks, Libraries, and Embedded Content' in Xcode")
            return false
        }
        #endif
    }
}

