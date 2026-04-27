//
//  FirebaseSyncService.swift
//  Faith Journal
//
//  Firebase sync service for cross-device synchronization
//

import Foundation
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@MainActor
@available(iOS 17.0, *)
class FirebaseSyncService: ObservableObject {
    static let shared = FirebaseSyncService()

    /// One-time log: participant count is skipped when `Auth` has no user (Firestore rules require `request.auth` for `liveSessions` updates).
    private static var didLogParticipantCountRequiresSignIn = false
    private static var didLogInviteCodeIndexSkippedNoAuth = false
    
    #if canImport(FirebaseFirestore)
    private var _db: Firestore?
    private var listener: ListenerRegistration?
    private var prayerRequestListener: ListenerRegistration?
    private var invitationListener: ListenerRegistration?
    private var friendSessionAlertsListener: ListenerRegistration?
    private var prayerIntercessorAlertsListener: ListenerRegistration?
    /// Skip scheduling notifications for the first snapshot (existing alerts); only notify for new alerts.
    private var hasReceivedInitialFriendAlertsSnapshot = false
    /// Same pattern for prayer intercessor alerts (someone prayed for you).
    private var hasReceivedInitialPrayerIntercessorSnapshot = false
    /// Same pattern for session invitations (avoid spamming for historical invites on first connect).
    private var hasReceivedInitialInvitationSnapshot = false

    #if canImport(FirebaseAuth)
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    #endif
    
    /// Lazy Firestore database access - only initializes after Firebase is configured
    private var db: Firestore? {
        if _db == nil {
            // Check if Firebase is configured before accessing Firestore
            guard FirebaseInitializer.shared.isConfigured else {
                print("⚠️ [FIREBASE SYNC] Firebase not configured yet - cannot access Firestore")
                return nil
            }
            
            // Initialize Firestore only after Firebase is configured
            _db = Firestore.firestore()
            // IMPORTANT:
            // Do NOT set Firestore settings here. Firestore only allows settings to be set
            // before any other Firestore usage; doing it here can crash if Firestore was
            // touched elsewhere already (e.g., during app init / other services).
            print("✅ [FIREBASE SYNC] Firestore initialized")
        }
        return _db
    }
    #else
    private let db: Any? = nil
    #endif

    #if canImport(FirebaseStorage)
    private var storage: Storage? {
        guard FirebaseInitializer.shared.isConfigured else { return nil }
        return Storage.storage()
    }
    #endif
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    /// Pending incoming friend request count; refresh via refreshPendingFriendRequestCount() (e.g. on app active / More tab).
    @Published var pendingFriendRequestCount: Int = 0
    @Published var latestFriendSessionAlert: FriendSessionAlert? = nil

    struct FriendSessionAlert: Identifiable {
        let id = UUID()
        let hostName: String
        let sessionTitle: String
        let sessionId: String
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    private init() {
        #if canImport(FirebaseFirestore)
        // Don't initialize Firestore here - wait until Firebase is configured
        // This prevents "Failed to get FirebaseApp instance" errors
        print("ℹ️ [FIREBASE SYNC] Service initialized - Firestore will be created when needed")
        #else
        print("⚠️ [FIREBASE] FirebaseFirestore not available - sync disabled")
        #endif
    }
    
    // MARK: - Setup
    
    /// Configure the sync service with a ModelContext
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        guard FirebaseInitializer.shared.isConfigured else {
            print("⚠️ [FIREBASE] Sync not configured yet - Firebase not initialized (check GoogleService-Info.plist)")
            return
        }

        // Ensure sync starts immediately after sign-in (if configure() ran before login).
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        installAuthStateListenerIfNeeded()
        #endif
        
        // For simulator testing, use shared test user ID for cross-device sync
        // Note: This requires Firestore security rules to allow unauthenticated access
        // OR the rules need to be updated to allow this specific test user
        #if targetEnvironment(simulator)
        // Use shared test user ID so both simulators can sync with each other
        if let userId = getCurrentUserId() {
            print("✅ [FIREBASE] Using shared test user ID for simulator sync testing: \(userId)")
            print("✅ [FIREBASE] Both simulators will use this same ID to test cross-device sync")
            // Test Firebase connectivity first
            Task {
                await testFirebaseConnection()
            }
            startListening()
            Task {
                await ensureCurrentUserInSearchProfiles()
                await ensureFriendCodeOnSignIn()
            }
            return
        }
        #endif
        
        // Check if user is authenticated before starting listener
        if let userId = getCurrentUserId() {
            print("✅ [FIREBASE] User authenticated: \(userId), starting listener")
            Task {
                await testFirebaseConnection()
                await ensureCurrentUserInSearchProfiles()
                await ensureFriendCodeOnSignIn()
            }
            startListening()
        } else {
            print("⚠️ [FIREBASE] User not authenticated yet, listener will start after sign-in")
            // Delayed retry: Auth may restore asynchronously shortly after app launch
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                if self.modelContext != nil, getCurrentUserId() != nil {
                    print("✅ [FIREBASE] Auth restored late - starting listener now")
                    self.syncError = nil
                    startListening()
                    await syncAllData()
                    await ensureCurrentUserInSearchProfiles()
                    await ensureFriendCodeOnSignIn()
                }
            }
        }
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func installAuthStateListenerIfNeeded() {
        guard authStateListenerHandle == nil else { return }
        
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    print("✅ [FIREBASE] Auth state changed: signed in (\(user.uid))")
                    self.syncError = nil
                    guard self.modelContext != nil else {
                        print("⚠️ [FIREBASE] ModelContext not set yet; will start listening after configure(modelContext:)")
                        return
                    }
                    
                    // Start listeners + run an initial sync right away.
                    self.restartListening()
                    await self.syncAllData()
                    
                    // Refresh profile after sign-in.
                    await ProfileManager.shared.loadProfile()
                    // Ensure user is in Faith Friends search index (uses users/ or local UserProfile)
                    await self.ensureCurrentUserInSearchProfiles()
                    // Create friend code immediately so it's ready before user opens Faith Friends
                    await self.ensureFriendCodeOnSignIn()
                } else {
                    print("⚠️ [FIREBASE] Auth state changed: signed out")
                    self.stopListeningInternal()
                    NotificationService.shared.cancelAdminAdMobEarningsReminder()
                    await ProfileManager.shared.refreshFirebaseAppAdminClaim()
                }
            }
        }
        
        print("✅ [FIREBASE] Installed Auth state listener")
    }
    #endif

    private func stopListeningInternal() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        prayerRequestListener?.remove()
        prayerRequestListener = nil
        invitationListener?.remove()
        invitationListener = nil
        friendSessionAlertsListener?.remove()
        friendSessionAlertsListener = nil
        prayerIntercessorAlertsListener?.remove()
        prayerIntercessorAlertsListener = nil
        hasReceivedInitialFriendAlertsSnapshot = false
        hasReceivedInitialPrayerIntercessorSnapshot = false
        hasReceivedInitialInvitationSnapshot = false
        #endif
    }
    
    /// Test Firebase connection by writing a test document
    /// This creates a test collection to verify Firebase is working
    /// Call this to diagnose sync issues
    func testFirebaseConnection() async {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ [FIREBASE TEST] Cannot test - Firebase Firestore not available")
            return
        }
        
        // Get user ID - use test user ID if not authenticated (for simulator/testing)
        var userId = getCurrentUserId()
        if userId == nil {
            // Force use test user ID for testing
            userId = "simulator-test-user-shared"
            print("⚠️ [FIREBASE TEST] No authenticated user, using test user ID: \(userId!)")
        }
        
        guard let userId = userId else {
            print("❌ [FIREBASE TEST] Cannot test - unable to determine user ID")
            return
        }
        
        // Check Firebase Auth status
        #if canImport(FirebaseAuth)
        if let authUser = Auth.auth().currentUser {
            print("🔑 [FIREBASE TEST] Firebase Auth User:")
            print("   - UID: \(authUser.uid)")
            print("   - Email: \(authUser.email ?? "none")")
            print("   - Provider: \(authUser.providerData.first?.providerID ?? "none")")
        } else {
            print("⚠️ [FIREBASE TEST] No Firebase Auth user - using test user ID")
        }
        #endif
        
        print("🧪 [FIREBASE TEST] ========================================")
        print("🧪 [FIREBASE TEST] Testing Firebase connection...")
        print("🧪 [FIREBASE TEST] User ID: \(userId)")
        #if os(iOS)
        print("🧪 [FIREBASE TEST] Device: \(UIDevice.current.name)")
        #else
        print("🧪 [FIREBASE TEST] Device: \(ProcessInfo.processInfo.hostName)")
        #endif
        print("🧪 [FIREBASE TEST] ========================================")
        
        // Check Firebase Auth status
        #if canImport(FirebaseAuth)
        if let authUser = Auth.auth().currentUser {
            print("🔑 [FIREBASE TEST] Firebase Auth User:")
            print("   - UID: \(authUser.uid)")
            print("   - Email: \(authUser.email ?? "none")")
            print("   - Provider: \(authUser.providerData.first?.providerID ?? "none")")
        } else {
            print("⚠️ [FIREBASE TEST] No Firebase Auth user - using test user ID")
        }
        #endif
        
        do {
            // Write test document to user's subcollection (this works with security rules)
            // The catch-all rule allows any subcollection under users/{userId}
            let userTestRef = db.collection("users").document(userId)
                .collection("testConnection").document("test")
            
            let deviceName: String = {
                #if os(iOS)
                return UIDevice.current.name
                #else
                return ProcessInfo.processInfo.hostName
                #endif
            }()
            let testData: [String: Any] = [
                "timestamp": Timestamp(date: Date()),
                "device": deviceName,
                "test": true,
                "message": "This is a test document to verify Firebase connectivity",
                "userId": userId,
                "createdAt": Timestamp(date: Date()),
                "testRun": Date().timeIntervalSince1970
            ]
            
            print("🧪 [FIREBASE TEST] Attempting to write test document...")
            print("🧪 [FIREBASE TEST] Full path: users/\(userId)/testConnection/test")
            print("🧪 [FIREBASE TEST] This path is allowed by Firestore security rules")
            print("🧪 [FIREBASE TEST] Writing document now...")
            
            try await userTestRef.setData(testData)
            print("✅ [FIREBASE TEST] ========================================")
            print("✅ [FIREBASE TEST] Test document written successfully!")
            print("✅ [FIREBASE TEST] Path: users/\(userId)/testConnection/test")
            print("✅ [FIREBASE TEST] ========================================")
            print("✅ [FIREBASE TEST] Check Firebase Console → Firestore Database:")
            print("   1. Click on 'users' collection")
            print("   2. Click on document with ID: \(userId)")
            print("   3. You should see 'testConnection' subcollection")
            print("   4. Inside testConnection, you should see 'test' document")
            print("✅ [FIREBASE TEST] If you see this, Firebase is working!")
            print("✅ [FIREBASE TEST] Journal entries will sync to: users/\(userId)/journalEntries")
            print("✅ [FIREBASE TEST] ========================================")
            
            // Also create a top-level test collection for easier visibility
            let topLevelTestRef = db.collection("testConnection").document("initial-test")
            let topLevelData: [String: Any] = [
                "timestamp": Timestamp(date: Date()),
                "device": deviceName,
                "test": true,
                "message": "Initial test collection - Firebase is working!",
                "userId": userId,
                "createdAt": Timestamp(date: Date())
            ]
            
            print("🧪 [FIREBASE TEST] Creating top-level test collection for visibility...")
            try await topLevelTestRef.setData(topLevelData)
            print("✅ [FIREBASE TEST] Top-level test collection created: testConnection/initial-test")
            print("✅ [FIREBASE TEST] You should see 'testConnection' collection in Firebase Console")
            
            // Verify we can read it back
            print("🧪 [FIREBASE TEST] Verifying document exists...")
            let verifyDoc = try? await userTestRef.getDocument()
            if let doc = verifyDoc, doc.exists == true {
                print("✅ [FIREBASE TEST] Verified: Test document exists and is readable")
                if let data = doc.data() {
                    print("✅ [FIREBASE TEST] Document data keys: \(data.keys.joined(separator: ", "))")
                }
                print("✅ [FIREBASE TEST] Firebase read/write is working correctly!")
            } else {
                print("⚠️ [FIREBASE TEST] Warning: Test document written but cannot be read back")
                print("⚠️ [FIREBASE TEST] This might indicate a security rules issue")
                print("⚠️ [FIREBASE TEST] Check that Firestore rules allow authenticated users to read their own data")
            }
        } catch {
            print("❌ [FIREBASE TEST] ========================================")
            print("❌ [FIREBASE TEST] FAILED to write test document!")
            print("❌ [FIREBASE TEST] Error: \(error.localizedDescription)")
            print("❌ [FIREBASE TEST] Full error: \(error)")
            
            let nsError = error as NSError
            print("❌ [FIREBASE TEST] Error code: \(nsError.code)")
            print("❌ [FIREBASE TEST] Error domain: \(nsError.domain)")
            print("❌ [FIREBASE TEST] Error userInfo: \(nsError.userInfo)")
            
            // Check for common error codes
            if nsError.domain == "FIRFirestoreErrorDomain" {
                switch nsError.code {
                case 7: // PERMISSION_DENIED
                    print("❌ [FIREBASE TEST] ========================================")
                    print("❌ [FIREBASE TEST] PERMISSION_DENIED Error!")
                    print("❌ [FIREBASE TEST] This means Firestore security rules are blocking the write")
                    print("❌ [FIREBASE TEST] Current user ID: \(userId)")
                    #if canImport(FirebaseAuth)
                    if let authUser = Auth.auth().currentUser {
                        print("❌ [FIREBASE TEST] Firebase Auth UID: \(authUser.uid)")
                        print("❌ [FIREBASE TEST] User ID matches Auth UID: \(userId == authUser.uid)")
                    } else {
                        print("❌ [FIREBASE TEST] No Firebase Auth user - using test user ID")
                        print("❌ [FIREBASE TEST] Security rules must allow test user ID: simulator-test-user-shared")
                    }
                    #endif
                    print("❌ [FIREBASE TEST] ========================================")
                    print("❌ [FIREBASE TEST] SOLUTION:")
                    print("   1. Go to Firebase Console → Firestore → Rules")
                    print("   2. Make sure rules allow writes for user ID: \(userId)")
                    print("   3. If using test user, rules must allow: simulator-test-user-shared")
                    print("   4. Deploy the updated rules")
                    print("❌ [FIREBASE TEST] ========================================")
                    syncError = "Permission denied - check Firestore security rules. User ID: \(userId)"
                case 14: // UNAVAILABLE
                    print("❌ [FIREBASE TEST] UNAVAILABLE - Firebase service is unavailable")
                    print("❌ [FIREBASE TEST] Check your internet connection")
                    syncError = "Firebase service unavailable - check internet connection"
                case 3: // INVALID_ARGUMENT
                    print("❌ [FIREBASE TEST] INVALID_ARGUMENT - Check data format")
                    syncError = "Invalid data format"
                case 4: // DEADLINE_EXCEEDED
                    print("❌ [FIREBASE TEST] DEADLINE_EXCEEDED - Request timed out")
                    syncError = "Request timed out - check internet connection"
                default:
                    print("❌ [FIREBASE TEST] Unknown Firestore error code: \(nsError.code)")
                    syncError = "Firebase error (code \(nsError.code)): \(error.localizedDescription)"
                }
            } else if nsError.domain.contains("Auth") {
                print("❌ [FIREBASE TEST] Authentication error - user may not be authenticated")
                syncError = "Authentication error: \(error.localizedDescription)"
            } else {
                print("❌ [FIREBASE TEST] Unknown error domain: \(nsError.domain)")
                syncError = "Error: \(error.localizedDescription)"
            }
            print("❌ [FIREBASE TEST] ========================================")
            
            // Set sync error so UI can display it
            await MainActor.run {
                self.syncError = syncError
            }
        }
        #endif
    }
    
    /// Restart the listener (call this after user signs in or when app becomes active)
    func restartListening() {
        #if canImport(FirebaseFirestore)
        // Remove existing listeners if any
        stopListeningInternal()
        
        // Ensure modelContext is set (might not be if called before configure)
        guard modelContext != nil else {
            print("⚠️ [FIREBASE] Cannot restart listener - modelContext not set. Call configure() first.")
            print("⚠️ [FIREBASE] Listener will start automatically when AppRootView configures the service.")
            return
        }
        
        // Check if user is authenticated before starting listener
        if let userId = getCurrentUserId() {
            print("✅ [FIREBASE] User authenticated: \(userId), restarting listener")
            // Test Firebase connection when restarting (especially after sign-in)
            Task {
                await testFirebaseConnection()
            }
            startListening()
            print("🔄 [FIREBASE] Restarted Firebase listeners for authenticated user")
        } else {
            print("⚠️ [FIREBASE] Cannot restart listener - user not authenticated yet")
            print("⚠️ [FIREBASE] Listener will start automatically after sign-in")
        }
        #endif
    }
    
    // MARK: - Journal Entries Sync
    
    /// Sync a journal entry to Firebase.
    /// - Parameter updateSyncState: If true (default), updates isSyncing for UI. Set to false when called from syncAllData so the full-sync indicator stays active.
    func syncJournalEntry(_ entry: JournalEntry, updateSyncState: Bool = true) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ [FIREBASE] Cannot sync - Firebase Firestore not available")
            syncError = "Firebase not configured"
            return
        }
        
        var userId = getCurrentUserId()
        if userId == nil {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            userId = getCurrentUserId()
        }
        guard let userId = userId else {
            print("❌ [FIREBASE] Cannot sync - user not authenticated")
            print("❌ [FIREBASE] User must sign in with Apple for sync to work")
            syncError = "User not authenticated. Please sign in with Apple."
            return
        }
        
        if updateSyncState {
            isSyncing = true
        }
        syncError = nil
        defer { if updateSyncState { isSyncing = false } }
        
        do {
            let entryRef = db.collection("users").document(userId)
                .collection("journalEntries").document(entry.id.uuidString)
            
            var data: [String: Any] = [
                "id": entry.id.uuidString,
                "title": entry.title,
                "content": entry.content,
                "date": Timestamp(date: entry.date),
                "tags": entry.tags,
                "mood": entry.mood ?? NSNull(),
                "location": entry.location ?? NSNull(),
                "isPrivate": entry.isPrivate,
                "createdAt": Timestamp(date: entry.createdAt),
                "updatedAt": Timestamp(date: entry.updatedAt),
                "lastSyncedAt": Timestamp(date: Date())
            ]
            if let pid = entry.linkedPrayerRequestId {
                data["linkedPrayerRequestId"] = pid.uuidString
            } else {
                data["linkedPrayerRequestId"] = NSNull()
            }
            if let rid = entry.linkedReadingPlanId {
                data["linkedReadingPlanId"] = rid.uuidString
            } else {
                data["linkedReadingPlanId"] = NSNull()
            }
            if let rd = entry.linkedReadingDay {
                data["linkedReadingDay"] = rd
            } else {
                data["linkedReadingDay"] = NSNull()
            }
            
            try await entryRef.setData(data, merge: true)
            lastSyncDate = Date()
            print("✅ [FIREBASE] Synced journal entry: \(entry.id.uuidString)")
            print("✅ [FIREBASE] Entry title: \(entry.title)")
            print("✅ [FIREBASE] User ID: \(userId)")
            print("✅ [FIREBASE] Firestore path: users/\(userId)/journalEntries/\(entry.id.uuidString)")
            print("✅ [FIREBASE] Entry will appear on other devices via listener")
            
            // Verify the write succeeded by checking if document exists
            let verifyDoc = try? await entryRef.getDocument()
            if verifyDoc?.exists == true {
                print("✅ [FIREBASE] Verified: Entry exists in Firebase and is readable")
                if let verifyData = verifyDoc?.data() {
                    print("✅ [FIREBASE] Verified data keys: \(verifyData.keys.joined(separator: ", "))")
                    print("✅ [FIREBASE] Collection 'journalEntries' should now be visible in Firebase Console")
                }
            } else {
                print("⚠️ [FIREBASE] Warning: Could not verify entry exists in Firebase")
                print("⚠️ [FIREBASE] This might indicate a Firestore security rules issue")
                print("⚠️ [FIREBASE] Check Firebase Console → Firestore Database → Rules")
            }
        } catch {
            syncError = error.localizedDescription
            print("❌ [FIREBASE] Failed to sync journal entry: \(error.localizedDescription)")
            print("❌ [FIREBASE] Error details: \(error)")
            
            // Log detailed error information for debugging
            let nsError = error as NSError
            print("❌ [FIREBASE] Error code: \(nsError.code)")
            print("❌ [FIREBASE] Error domain: \(nsError.domain)")
            
            // Check for common error codes
            if nsError.domain == "FIRFirestoreErrorDomain" {
                switch nsError.code {
                case 7: // PERMISSION_DENIED
                    print("❌ [FIREBASE] PERMISSION_DENIED - Check Firestore security rules")
                    print("❌ [FIREBASE] Make sure rules allow authenticated users to write to their own data")
                    syncError = "Permission denied - check Firestore security rules"
                case 14: // UNAVAILABLE
                    print("❌ [FIREBASE] UNAVAILABLE - Firebase service is unavailable")
                    syncError = "Firebase service unavailable - check internet connection"
                default:
                    syncError = "Firebase error (code \(nsError.code)): \(error.localizedDescription)"
                }
            }
        }
        #else
        print("⚠️ [FIREBASE] Firebase not available - cannot sync")
        #endif
    }
    
    // MARK: - Devotional Completions Sync
    
    /// Sync a devotional completion status to Firebase
    func syncDevotionalCompletion(_ completion: DevotionalCompletion) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ [FIREBASE] Cannot sync devotional completion - Firebase Firestore not available")
            return
        }
        
        guard let userId = getCurrentUserId() else {
            print("❌ [FIREBASE] Cannot sync devotional completion - user not authenticated")
            return
        }
        
        print("🔄 [FIREBASE] Syncing devotional completion for user: \(userId)")
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            let dateString = dateFormatter.string(from: completion.devotionalDate)
            
            let completionRef = db.collection("users").document(userId)
                .collection("devotionalCompletions").document(dateString)
            
            let data: [String: Any] = [
                "id": completion.id.uuidString,
                "devotionalId": completion.devotionalId.uuidString,
                "devotionalDate": Timestamp(date: completion.devotionalDate),
                "isCompleted": completion.isCompleted,
                "completedAt": completion.completedAt != nil ? Timestamp(date: completion.completedAt!) : NSNull(),
                "createdAt": Timestamp(date: completion.createdAt),
                "updatedAt": Timestamp(date: completion.updatedAt),
                "lastSyncedAt": Timestamp(date: Date())
            ]
            
            try await completionRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced devotional completion for date: \(dateString), isCompleted: \(completion.isCompleted)")
        } catch {
            print("❌ [FIREBASE] Failed to sync devotional completion: \(error.localizedDescription)")
        }
        #else
        print("⚠️ [FIREBASE] Firebase not available - cannot sync devotional completion")
        #endif
    }
    
    /// Delete a journal entry from Firebase
    func deleteJournalEntry(_ entry: JournalEntry) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let entryRef = db.collection("users").document(userId)
                .collection("journalEntries").document(entry.id.uuidString)
            
            try await entryRef.delete()
            print("✅ [FIREBASE] Deleted journal entry: \(entry.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete journal entry: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Start listening for remote changes
    private func startListening() {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else {
            print("⚠️ [FIREBASE] Cannot start listener - user not authenticated")
            print("⚠️ [FIREBASE] User must sign in with Apple for cross-device sync to work")
            return
        }
        
        // Remove existing listeners if any
        stopListeningInternal()
        
        print("👂 [FIREBASE] Starting Firebase listener for user: \(userId)")
        print("👂 [FIREBASE] Listening to path: users/\(userId)/journalEntries")
        
        // Listen for journal entries - include metadata changes to catch all updates
        listener = db.collection("users").document(userId)
            .collection("journalEntries")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [FIREBASE] Listen error: \(error.localizedDescription)")
                    print("❌ [FIREBASE] Error code: \((error as NSError).code)")
                    print("❌ [FIREBASE] Error domain: \((error as NSError).domain)")
                    self.syncError = error.localizedDescription
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ [FIREBASE] Snapshot is nil")
                    return
                }
                
                let isInitialSnapshot = snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites
                let hasPendingWrites = snapshot.metadata.hasPendingWrites
                print("📥 [FIREBASE] Received snapshot:")
                print("   - Changes: \(snapshot.documentChanges.count)")
                print("   - Total documents: \(snapshot.documents.count)")
                print("   - Is initial: \(isInitialSnapshot)")
                print("   - From cache: \(snapshot.metadata.isFromCache)")
                print("   - Has pending writes: \(hasPendingWrites)")
                
                // Process all documents on initial snapshot to ensure we have all entries
                if isInitialSnapshot && snapshot.documents.count > 0 {
                    print("📥 [FIREBASE] Processing initial snapshot with \(snapshot.documents.count) existing entries")
                    Task { @MainActor in
                        for document in snapshot.documents {
                            let data = document.data()
                            let entryId = document.documentID
                            print("📝 [FIREBASE] Processing initial entry: \(entryId)")
                            
                            // Check if entry exists locally
                            // Convert entryId string to UUID for comparison
                            guard let entryUUID = UUID(uuidString: entryId) else {
                                print("⚠️ [FIREBASE] Invalid entry ID format: \(entryId)")
                                continue
                            }
                            let descriptor = FetchDescriptor<JournalEntry>(
                                predicate: #Predicate<JournalEntry> { $0.id == entryUUID }
                            )
                            
                            if let existingEntry = try? self.modelContext?.fetch(descriptor).first {
                                // Update existing entry if remote is newer
                                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                                    if remoteUpdatedAt.dateValue() > existingEntry.updatedAt {
                                        print("📥 [FIREBASE] Updating local entry from initial snapshot")
                                        self.updateLocalEntry(existingEntry, with: data)
                                    }
                                }
                            } else {
                                // Create new entry from initial snapshot
                                print("➕ [FIREBASE] Creating local entry from initial snapshot")
                                self.createLocalEntry(from: data, id: entryId)
                            }
                        }
                    }
                }
                
                // Process document changes (new/modified/deleted entries)
                if snapshot.documentChanges.count > 0 {
                    print("📥 [FIREBASE] Processing \(snapshot.documentChanges.count) document changes")
                    Task { @MainActor in
                        for documentChange in snapshot.documentChanges {
                            print("📝 [FIREBASE] Processing change type: \(documentChange.type.rawValue) for entry: \(documentChange.document.documentID)")
                            self.handleDocumentChange(documentChange)
                        }
                    }
                }
            }
        
        // Listen for session invitations
        invitationListener = db.collection("users").document(userId)
            .collection("sessionInvitations")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [FIREBASE] Invitation listen error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                print("📥 [FIREBASE] Received \(snapshot.documentChanges.count) invitation changes")
                // Ensure we're on MainActor for ModelContext operations
                Task { @MainActor in
                    let suppressInviteNotifications = !self.hasReceivedInitialInvitationSnapshot
                    if !self.hasReceivedInitialInvitationSnapshot {
                        self.hasReceivedInitialInvitationSnapshot = true
                    }
                    for documentChange in snapshot.documentChanges {
                        self.handleInvitationChange(documentChange, suppressInviteNotification: suppressInviteNotifications)
                    }
                }
            }
        
        // Listen for friend session alerts (when a friend starts a live session)
        friendSessionAlertsListener = db.collection("users").document(userId)
            .collection("friendSessionAlerts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ [FIREBASE] Friend session alerts listen error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot else { return }
                // Firestore delivers existing documents as .added on the first snapshot; skip to avoid multiple/stale notifications.
                if !self.hasReceivedInitialFriendAlertsSnapshot {
                    self.hasReceivedInitialFriendAlertsSnapshot = true
                    return
                }
                for change in snapshot.documentChanges where change.type == .added {
                    let data = change.document.data()
                    let sessionId = change.document.documentID
                    let hostName = data["hostName"] as? String ?? "A friend"
                    let sessionTitle = data["sessionTitle"] as? String ?? "Live Session"
                    Task { @MainActor in
                        NotificationService.shared.scheduleFriendSessionNotification(
                            hostName: hostName,
                            sessionTitle: sessionTitle,
                            sessionId: sessionId
                        )
                        self.latestFriendSessionAlert = FriendSessionAlert(
                            hostName: hostName,
                            sessionTitle: sessionTitle,
                            sessionId: sessionId
                        )
                    }
                }
            }
        
        // When a friend taps "Pray" on your shared prayer, they write users/{you}/prayerIntercessorAlerts/{prayerId}-{theirUid}
        prayerIntercessorAlertsListener = db.collection("users").document(userId)
            .collection("prayerIntercessorAlerts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ [FIREBASE] Prayer intercessor alerts listen error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot else { return }
                if !self.hasReceivedInitialPrayerIntercessorSnapshot {
                    self.hasReceivedInitialPrayerIntercessorSnapshot = true
                    return
                }
                for change in snapshot.documentChanges where change.type == .added {
                    let data = change.document.data()
                    let docId = change.document.documentID
                    let intercessorName = data["intercessorName"] as? String ?? "A friend"
                    let prayerId = data["prayerId"] as? String ?? ""
                    Task { @MainActor in
                        NotificationService.shared.schedulePrayerIntercessorNotification(
                            intercessorName: intercessorName,
                            prayerId: prayerId,
                            alertDocumentId: docId
                        )
                    }
                }
            }
        
        print("✅ [FIREBASE] Firebase listeners started successfully")
        #endif
    }
    
    /// Handle document changes from Firebase
    #if canImport(FirebaseFirestore)
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let modelContext = modelContext else {
            print("⚠️ [FIREBASE] Cannot handle change - modelContext is nil")
            return
        }
        
        let data = change.document.data()
        let entryId = change.document.documentID
        
        print("🔄 [FIREBASE] Handling change: type=\(change.type.rawValue), entryId=\(entryId)")
        
        switch change.type {
        case .added:
            // New entry from Firebase - check if it exists locally
            // Convert entryId string to UUID for comparison
            guard let entryUUID = UUID(uuidString: entryId) else {
                print("⚠️ [FIREBASE] Invalid entry ID format: \(entryId)")
                return
            }
            let descriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.id == entryUUID }
            )
            
            if let existingEntry = try? modelContext.fetch(descriptor).first {
                // Entry exists locally - check if remote is newer
                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                    if remoteUpdatedAt.dateValue() > existingEntry.updatedAt {
                        print("📥 [FIREBASE] Remote entry is newer, updating local entry")
                        updateLocalEntry(existingEntry, with: data)
                    } else {
                        print("ℹ️ [FIREBASE] Local entry is same or newer, skipping update")
                    }
                } else {
                    print("⚠️ [FIREBASE] Remote entry missing updatedAt, updating anyway")
                    updateLocalEntry(existingEntry, with: data)
                }
            } else {
                // Entry doesn't exist locally - create it
                print("➕ [FIREBASE] Creating new local entry from Firebase")
                createLocalEntry(from: data, id: entryId)
            }
            
        case .modified:
            // Entry was modified in Firebase - update local if newer
            // Convert entryId string to UUID for comparison
            guard let entryUUID = UUID(uuidString: entryId) else {
                print("⚠️ [FIREBASE] Invalid entry ID format: \(entryId)")
                return
            }
            let descriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.id == entryUUID }
            )
            
            if let existingEntry = try? modelContext.fetch(descriptor).first {
                // Check if remote is newer
                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                    if remoteUpdatedAt.dateValue() > existingEntry.updatedAt {
                        print("📥 [FIREBASE] Remote entry modified and is newer, updating local")
                        updateLocalEntry(existingEntry, with: data)
                    } else {
                        print("ℹ️ [FIREBASE] Local entry is newer, skipping remote update")
                    }
                } else {
                    print("📥 [FIREBASE] Remote entry modified (no updatedAt), updating local")
                    updateLocalEntry(existingEntry, with: data)
                }
            } else {
                // Entry was modified but doesn't exist locally - create it
                print("➕ [FIREBASE] Modified entry doesn't exist locally, creating it")
                createLocalEntry(from: data, id: entryId)
            }
            
        case .removed:
            // Entry was deleted in Firebase - delete local
            print("🗑️ [FIREBASE] Entry deleted in Firebase, removing local")
            // Convert entryId string to UUID for comparison
            guard let entryUUID = UUID(uuidString: entryId) else {
                print("⚠️ [FIREBASE] Invalid entry ID format: \(entryId)")
                return
            }
            let descriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.id == entryUUID }
            )
            if let entry = try? modelContext.fetch(descriptor).first {
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                    print("✅ [FIREBASE] Deleted local entry: \(entryId)")
                } catch {
                    print("❌ [FIREBASE] Failed to save deletion: \(error.localizedDescription)")
                }
            } else {
                print("ℹ️ [FIREBASE] Entry to delete not found locally: \(entryId)")
            }
        }
        
        // Listen for prayer requests - include metadata changes to catch all updates
        guard let userId = getCurrentUserId() else {
            print("⚠️ [FIREBASE] Cannot start prayer request listener - user not authenticated")
            return
        }
        print("👂 [FIREBASE] Starting prayer request listener for user: \(userId)")
        print("👂 [FIREBASE] Listening to path: users/\(userId)/prayerRequests")
        
        guard let db = db else {
            print("⚠️ [FIREBASE] Cannot start prayer request listener - Firestore not available")
            return
        }
        
        prayerRequestListener = db.collection("users").document(userId)
            .collection("prayerRequests")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [FIREBASE] Prayer request listen error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ [FIREBASE] Prayer request snapshot is nil")
                    return
                }
                
                let isInitialSnapshot = snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites
                print("📥 [FIREBASE] Prayer request snapshot:")
                print("   - Changes: \(snapshot.documentChanges.count)")
                print("   - Total documents: \(snapshot.documents.count)")
                print("   - Is initial: \(isInitialSnapshot)")
                
                // Process all documents on initial snapshot
                if isInitialSnapshot && snapshot.documents.count > 0 {
                    print("📥 [FIREBASE] Processing initial prayer request snapshot with \(snapshot.documents.count) existing requests")
                    Task { @MainActor in
                        for document in snapshot.documents {
                            let data = document.data()
                            let requestId = document.documentID
                            print("🙏 [FIREBASE] Processing initial prayer request: \(requestId)")
                            
                            guard let requestUUID = UUID(uuidString: requestId) else {
                                print("⚠️ [FIREBASE] Invalid prayer request ID format: \(requestId)")
                                continue
                            }
                            let descriptor = FetchDescriptor<PrayerRequest>(
                                predicate: #Predicate<PrayerRequest> { $0.id == requestUUID }
                            )
                            
                            if let existingRequest = try? self.modelContext?.fetch(descriptor).first {
                                // Update existing request if remote is newer
                                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                                    if remoteUpdatedAt.dateValue() > existingRequest.updatedAt {
                                        print("📥 [FIREBASE] Updating local prayer request from initial snapshot")
                                        self.updateLocalPrayerRequest(existingRequest, with: data)
                                    }
                                }
                            } else {
                                // Create new request from Firebase
                                print("➕ [FIREBASE] Creating new local prayer request from initial snapshot")
                                self.createLocalPrayerRequest(from: data, id: requestId)
                            }
                        }
                    }
                } else {
                    // Process individual changes
                    for change in snapshot.documentChanges {
                        self.handlePrayerRequestChange(change)
                    }
                }
            }
    }
    #else
    private func handleDocumentChange(_ change: Any) {
        // Firebase not available
    }
    #endif
    
    /// Update local entry with Firebase data
    private func updateLocalEntry(_ entry: JournalEntry, with data: [String: Any]) {
        #if canImport(FirebaseFirestore)
        entry.title = data["title"] as? String ?? entry.title
        entry.content = data["content"] as? String ?? entry.content
        
        if let timestamp = data["date"] as? Timestamp {
            entry.date = timestamp.dateValue()
        }
        
        entry.tags = data["tags"] as? [String] ?? entry.tags
        entry.mood = data["mood"] as? String
        entry.location = data["location"] as? String
        entry.isPrivate = data["isPrivate"] as? Bool ?? false
        if let s = data["linkedPrayerRequestId"] as? String, let u = UUID(uuidString: s) {
            entry.linkedPrayerRequestId = u
        }
        if let s = data["linkedReadingPlanId"] as? String, let u = UUID(uuidString: s) {
            entry.linkedReadingPlanId = u
        } else if data["linkedReadingPlanId"] is NSNull {
            entry.linkedReadingPlanId = nil
        }
        if let d = data["linkedReadingDay"] as? Int {
            entry.linkedReadingDay = d
        } else if data["linkedReadingDay"] is NSNull {
            entry.linkedReadingDay = nil
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            entry.updatedAt = timestamp.dateValue()
        }
        
        try? modelContext?.save()
        print("✅ [FIREBASE] Updated local entry: \(entry.id.uuidString)")
        #endif
    }
    
    /// Create local entry from Firebase data
    private func createLocalEntry(from data: [String: Any], id: String) {
        #if canImport(FirebaseFirestore)
        guard let modelContext = modelContext,
              let uuid = UUID(uuidString: id) else { return }
        
        let entry = JournalEntry(
            title: data["title"] as? String ?? "",
            content: data["content"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            mood: data["mood"] as? String,
            location: data["location"] as? String,
            isPrivate: data["isPrivate"] as? Bool ?? false
        )
        
        entry.id = uuid
        
        if let timestamp = data["date"] as? Timestamp {
            entry.date = timestamp.dateValue()
        }
        
        if let timestamp = data["createdAt"] as? Timestamp {
            entry.createdAt = timestamp.dateValue()
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            entry.updatedAt = timestamp.dateValue()
        }
        if let s = data["linkedPrayerRequestId"] as? String, let u = UUID(uuidString: s) {
            entry.linkedPrayerRequestId = u
        }
        if let s = data["linkedReadingPlanId"] as? String, let u = UUID(uuidString: s) {
            entry.linkedReadingPlanId = u
        }
        if let d = data["linkedReadingDay"] as? Int {
            entry.linkedReadingDay = d
        }
        
        modelContext.insert(entry)
        try? modelContext.save()
        print("✅ [FIREBASE] Created local entry from Firebase: \(id)")
        #endif
    }
    
    // MARK: - Session Invitations Sync
    
    /// Sync a session invitation to Firebase
    func syncSessionInvitation(_ invitation: SessionInvitation) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else {
            print("⚠️ [FIREBASE] Cannot sync invitation - Firebase not configured or user not authenticated")
            return
        }
        
        do {
            let invitationRef = db.collection("users").document(userId)
                .collection("sessionInvitations").document(invitation.id.uuidString)
            
            let data: [String: Any] = [
                "id": invitation.id.uuidString,
                "sessionId": invitation.sessionId.uuidString,
                "sessionTitle": invitation.sessionTitle,
                "hostId": invitation.hostId,
                "hostName": invitation.hostName,
                "invitedUserId": invitation.invitedUserId ?? NSNull(),
                "invitedUserName": invitation.invitedUserName ?? NSNull(),
                "invitedEmail": invitation.invitedEmail ?? NSNull(),
                "inviteCode": invitation.inviteCode,
                "status": invitation.status.rawValue,
                "createdAt": Timestamp(date: invitation.createdAt),
                "respondedAt": invitation.respondedAt.map { Timestamp(date: $0) } ?? NSNull(),
                "expiresAt": invitation.expiresAt.map { Timestamp(date: $0) } ?? NSNull(),
                "lastSyncedAt": Timestamp(date: Date())
            ]
            
            try await invitationRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced session invitation: \(invitation.id.uuidString) (code: \(invitation.inviteCode))")

            // Also publish by invite code so other users can resolve codes cross-device.
            await publishInviteCode(invitation, db: db)
        } catch {
            print("❌ [FIREBASE] Failed to sync session invitation: \(error.localizedDescription)")
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func publishInviteCode(_ invitation: SessionInvitation, db: Firestore) async {
        let code = invitation.inviteCode.uppercased()
        guard !code.isEmpty else { return }
        // sessionInviteCodes: hostId must be request.auth.uid, or the simulator test id (see firestore.rules).
        #if canImport(FirebaseAuth)
        let indexHostId: String? = {
            if let u = Auth.auth().currentUser { return u.uid }
            if getCurrentUserId() == "simulator-test-user-shared" { return "simulator-test-user-shared" }
            // Signed-out real device: hostId could not match rules; skip to avoid permission spam.
            return nil
        }()
        guard let hostId = indexHostId else {
            if !Self.didLogInviteCodeIndexSkippedNoAuth {
                Self.didLogInviteCodeIndexSkippedNoAuth = true
                print("ℹ️ [INVITE CODE] Skipping public invite index (sign in to Firebase to publish; simulator uses test host id).")
            }
            return
        }
        #else
        let hostId = getCurrentUserId() ?? invitation.hostId
        #endif

        // A public-ish index for join-by-code. The Firestore rules should restrict what fields are readable.
        // Document id is the invite code for quick lookup.
        let ref = db.collection("sessionInviteCodes").document(code)
        let data: [String: Any] = [
            "inviteCode": code,
            "invitationId": invitation.id.uuidString,
            "sessionId": invitation.sessionId.uuidString,
            "sessionTitle": invitation.sessionTitle,
            "hostId": hostId,
            "hostName": invitation.hostName,
            "createdAt": Timestamp(date: invitation.createdAt),
            "expiresAt": invitation.expiresAt.map { Timestamp(date: $0) } ?? NSNull(),
            "lastSyncedAt": Timestamp(date: Date())
        ]

        do {
            // Refreshed token so `request.auth` in rules matches a signed-in host.
            if let user = Auth.auth().currentUser {
                _ = try? await user.getIDTokenResult(forcingRefresh: true)
            }
            try await ref.setData(data, merge: true)
            print("✅ [INVITE CODE] Published invite code index: \(code)")
        } catch {
            print("⚠️ [INVITE CODE] Failed to publish invite code index: \(error.localizedDescription)")
        }
    }

    /// Resolve an invite code via Firestore (cross-device join by code).
    /// Tries sessionInviteCodes first, then sessionInvitations (fallback for different sync paths).
    func fetchInviteCodeRecord(code: String) async -> [String: Any]? {
        // Try primary collection (sessionInviteCodes) first
        if let record = await fetchInviteCodeRecordFromSessionInviteCodes(code: code) {
            return record
        }
        // Fallback: some code paths publish to sessionInvitations with document id = code
        return await fetchInviteCodeRecordFromSessionInvitations(code: code)
    }

    /// Fetch invite code record from sessionInviteCodes collection.
    private func fetchInviteCodeRecordFromSessionInviteCodes(code: String) async -> [String: Any]? {
        guard let db = db else { return nil }
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        do {
            let snap = try await db.collection("sessionInviteCodes").document(normalized).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            if let expiresAt = data["expiresAt"] as? Timestamp, expiresAt.dateValue() <= Date() {
                print("⚠️ [INVITE CODE] sessionInviteCodes invite expired")
                return nil
            }
            return data
        } catch {
            print("⚠️ [INVITE CODE] Failed to fetch from sessionInviteCodes: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fallback: fetch invite code record from sessionInvitations (document id = code).
    /// Returns same shape as sessionInviteCodes so join flow can use it.
    private func fetchInviteCodeRecordFromSessionInvitations(code: String) async -> [String: Any]? {
        guard let db = db else { return nil }
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        do {
            let snap = try await db.collection("sessionInvitations").document(normalized).getDocument()
            guard snap.exists, let data = snap.data() else { return nil }
            // Check status and expiration (same semantics as sessionInvitations rules)
            let status = data["status"] as? String ?? ""
            if status != "pending" {
                print("⚠️ [INVITE CODE] sessionInvitations invite not pending: \(status)")
                return nil
            }
            if let expiresAt = data["expiresAt"] as? Timestamp {
                if expiresAt.dateValue() <= Date() {
                    print("⚠️ [INVITE CODE] sessionInvitations invite expired")
                    return nil
                }
            }
            // Return shape expected by join flow (sessionId, sessionTitle, hostId, hostName, expiresAt)
            return data
        } catch {
            print("⚠️ [INVITE CODE] Failed to fetch from sessionInvitations: \(error.localizedDescription)")
            return nil
        }
    }

    /// Publish a live session: **public** → top-level `liveSessions` (discovery); **private** → `users/{hostId}/liveSessions` (owner-only). Thumbnail is uploaded to Storage when still local.
    func syncLiveSessionPublic(_ session: LiveSession) async {
        guard let db = db else { return }
        // Firestore rules: hostId must equal request.auth.uid (signed-in user) or 'simulator-test-user-shared'.
        let firebaseUid = getCurrentUserId()
        let effectiveHostId = firebaseUid ?? session.hostId
        let isTestUser = (effectiveHostId == "simulator-test-user-shared")
        guard firebaseUid != nil || isTestUser else {
            print("⚠️ [LIVE SESSION] Cannot sync to Firebase - sign in required. Public sessions only appear for other accounts when the host is signed in (e.g. Sign in with Apple).")
            return
        }

        // Promote local file thumbnails to Storage first so merge includes `thumbnailURL` (Firestore only stores https).
        await ensureSessionThumbnailOnCloud(session: session)

        let ref: DocumentReference
        if session.isPrivate {
            ref = db.collection("users").document(effectiveHostId).collection("liveSessions").document(session.id.uuidString)
        } else {
            ref = db.collection("liveSessions").document(session.id.uuidString)
        }
        var data: [String: Any] = [
            "id": session.id.uuidString,
            "title": session.title,
            "details": session.details,
            "hostId": effectiveHostId,
            "hostName": session.hostName,
            "hostBio": session.hostBio,
            "category": session.category,
            "tags": session.tags,
            "isPrivate": session.isPrivate,
            "isActive": session.isActive,
            "maxParticipants": session.maxParticipants,
            "currentParticipants": session.currentParticipants,
            "currentBroadcasters": session.currentBroadcasters,
            "streamMode": session.streamMode,
            "durationLimitMinutes": session.durationLimitMinutes,
            "hasWaitingRoom": session.hasWaitingRoom,
            "waitingRoomEnabled": session.waitingRoomEnabled,
            "startTime": Timestamp(date: session.startTime),
            "scheduledStartTime": session.scheduledStartTime.map { Timestamp(date: $0) } ?? NSNull(),
            "endTime": session.endTime.map { Timestamp(date: $0) } ?? NSNull(),
            "createdAt": Timestamp(date: session.createdAt),
            "lastSyncedAt": Timestamp(date: Date())
        ]
        // Only include thumbnailURL when set and is a cloud URL (https). Omit when nil so we don't overwrite an existing thumbnail; omit file:// so other devices don't get a useless local path.
        if let url = session.thumbnailURL, !url.isEmpty, url.hasPrefix("https") {
            data["thumbnailURL"] = url
        }
        // Only include recordingURL when we have a cloud URL; don't overwrite with null.
        if let rec = session.recordingURL, !rec.hasPrefix("file://") {
            data["recordingURL"] = rec
        }

        do {
            try await ref.setData(data, merge: true)
            print("✅ [LIVE SESSION] Synced live session (\(session.isPrivate ? "private → users/\(effectiveHostId)/liveSessions" : "public → liveSessions")): \(session.id.uuidString)")
            // Do NOT notify friends here — notify only when host actually starts the stream
            // (see startLiveStream() in LiveSessionsView), to avoid notifying for sessions
            // that were just created or updated but not yet live.
        } catch {
            print("⚠️ [LIVE SESSION] Failed to sync live session to Firestore: \(error.localizedDescription)")
        }
    }

    /// Delete a live session from Firebase (host only - removes from liveSessions collection).
    func deleteLiveSession(_ session: LiveSession) async {
        await deleteLiveSession(sessionId: session.id, hostId: session.hostId)
    }

    /// Delete by id (use after session is removed from context to avoid accessing deleted object).
    /// Only attempts Firebase delete when the current user is the host (by app logic). Firestore allows delete when authenticated.
    func deleteLiveSession(sessionId: UUID, hostId: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        // Only the host (by app logic) should trigger cloud delete; must be signed in for Firestore to allow it
        guard getCurrentUserId() != nil else {
            print("⚠️ [FIREBASE] Cannot delete session from cloud - sign in required")
            return
        }
        let isAppHost = (hostId == (getCurrentUserId() ?? "")) || (hostId == "simulator-test-user-shared")
        guard isAppHost else {
            print("⚠️ [FIREBASE] Only the host can delete a session from Firebase")
            return
        }
        let ownerFirestoreId = getCurrentUserId() ?? hostId
        do {
            try await db.collection("liveSessions").document(sessionId.uuidString).delete()
        } catch {
            print("⚠️ [FIREBASE] Delete top-level liveSessions doc (may not exist for private-only): \(error.localizedDescription)")
        }
        do {
            try await db.collection("users").document(ownerFirestoreId).collection("liveSessions").document(sessionId.uuidString).delete()
            print("✅ [FIREBASE] Deleted live session from Firebase: \(sessionId.uuidString)")
        } catch {
            print("⚠️ [FIREBASE] Delete users/\(ownerFirestoreId)/liveSessions (may not exist): \(error.localizedDescription)")
        }
        #endif
    }

    /// Delete all live sessions in Firebase where the current user is the host (e.g. to remove test sessions).
    func deleteAllMyLiveSessionsFromFirebase() async -> Int {
        #if canImport(FirebaseFirestore)
        await ProfileManager.shared.refreshFirebaseAppAdminClaim()
        guard ProfileManager.shared.isFirebaseAppAdmin else {
            print("⚠️ [FIREBASE] deleteAllMyLiveSessionsFromFirebase denied — not an app admin (ID token custom claims)")
            return 0
        }
        guard let db = db else { return 0 }
        guard let hostId = getCurrentUserId() else {
            print("⚠️ [FIREBASE] Cannot delete live sessions - sign in required")
            return 0
        }
        do {
            let snapshot = try await db.collection("liveSessions")
                .whereField("hostId", isEqualTo: hostId)
                .getDocuments()
            var deleted = 0
            for document in snapshot.documents {
                try await document.reference.delete()
                deleted += 1
                print("✅ [FIREBASE] Deleted live session: \(document.documentID)")
            }
            if deleted > 0 {
                print("✅ [FIREBASE] Deleted \(deleted) live session(s) from Firebase (host: \(hostId))")
            }
            return deleted
        } catch {
            print("❌ [FIREBASE] Failed to delete live sessions: \(error.localizedDescription)")
            return 0
        }
        #else
        return 0
        #endif
    }

    /// Update live session participant count in Firebase so all clients see the correct count.
    /// Firestore rules: `match /liveSessions/{sessionId}` allows `update` only when `isAuthenticated()`.
    /// If the user is not signed in to Firebase (no ID token), the write is skipped so you do not get `PERMISSION_DENIED` spam; local SwiftData is still correct.
    func updateSessionParticipantCount(_ sessionId: UUID, count: Int) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            if !Self.didLogParticipantCountRequiresSignIn {
                Self.didLogParticipantCountRequiresSignIn = true
                print("ℹ️ [FIREBASE] liveSessions participant count is not synced to the cloud without Firebase sign-in. Local count still updates. Use Sign in with Apple (or your production auth flow) to sync across devices.")
            }
            return
        }
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: false)
        } catch {
            // Token refresh failure is rare; still attempt the write.
        }
        #endif
        do {
            let ref = db.collection("liveSessions").document(sessionId.uuidString)
            try await ref.updateData(["currentParticipants": count])
        } catch {
            let ns = error as NSError
            let isPermission = ns.domain == FirestoreErrorDomain
                && ns.code == FirestoreErrorCode.permissionDenied.rawValue
            if isPermission {
                print("❌ [FIREBASE] Failed to update participant count: missing permissions. Ensure you are signed in, `firestore.rules` for `liveSessions` are deployed, and the session document exists in `liveSessions` (host has synced a public session).")
            } else {
                print("❌ [FIREBASE] Failed to update participant count: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Fetch a live session from the public collection.
    func fetchLiveSessionPublic(sessionId: UUID) async -> LiveSession? {
        guard let db = db else { return nil }

        do {
            let snap = try await db.collection("liveSessions").document(sessionId.uuidString).getDocument()
            guard let data = snap.data(), snap.exists else { return nil }

            let title = data["title"] as? String ?? ""
            let details = data["details"] as? String ?? ""
            let hostId = data["hostId"] as? String ?? ""
            let category = data["category"] as? String ?? ""
            let maxParticipants = data["maxParticipants"] as? Int ?? 10
            let tags = data["tags"] as? [String] ?? []

            let session = LiveSession(title: title, description: details, hostId: hostId, category: category, maxParticipants: maxParticipants, tags: tags)
            session.id = sessionId
            session.hostName = data["hostName"] as? String ?? session.hostName
            session.hostBio = data["hostBio"] as? String ?? session.hostBio
            session.isPrivate = (data["isPrivate"] as? Bool) ?? false
            session.isActive = data["isActive"] as? Bool ?? session.isActive
            session.currentParticipants = data["currentParticipants"] as? Int ?? session.currentParticipants
            session.streamMode = data["streamMode"] as? String ?? session.streamMode
            session.durationLimitMinutes = data["durationLimitMinutes"] as? Int ?? session.durationLimitMinutes

            if let ts = data["startTime"] as? Timestamp { session.startTime = ts.dateValue() }
            if let ts = data["scheduledStartTime"] as? Timestamp { session.scheduledStartTime = ts.dateValue() }
            if let ts = data["endTime"] as? Timestamp { session.endTime = ts.dateValue() }
            if let ts = data["createdAt"] as? Timestamp { session.createdAt = ts.dateValue() }
            session.thumbnailURL = data["thumbnailURL"] as? String
            session.recordingURL = data["recordingURL"] as? String

            return session
        } catch {
            print("⚠️ [LIVE SESSION] Failed to fetch public live session: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch all public (non-private) live sessions for discovery.
    func fetchPublicSessions() async -> [LiveSession] {
        guard let db = db else {
            print("⚠️ [LIVE SESSION] Cannot fetch public sessions - Firestore not available")
            return []
        }

        do {
            let query = db.collection("liveSessions")
                .whereField("isPrivate", isEqualTo: false)
                .order(by: "startTime", descending: true)
                .limit(to: 50)

            let snapshot = try await query.getDocuments()
            var sessions: [LiveSession] = []

            for document in snapshot.documents {
                let data = document.data()
                guard let sessionId = UUID(uuidString: document.documentID) else { continue }

                let title = data["title"] as? String ?? ""
                let details = data["details"] as? String ?? ""
                let hostId = data["hostId"] as? String ?? ""
                let category = data["category"] as? String ?? ""
                let maxParticipants = data["maxParticipants"] as? Int ?? 10
                let tags = data["tags"] as? [String] ?? []

                let session = LiveSession(title: title, description: details, hostId: hostId, category: category, maxParticipants: maxParticipants, tags: tags)
                session.id = sessionId
                session.hostName = data["hostName"] as? String ?? session.hostName
                session.hostBio = data["hostBio"] as? String ?? session.hostBio
                session.isPrivate = (data["isPrivate"] as? Bool) ?? false
                session.isActive = data["isActive"] as? Bool ?? session.isActive
                session.currentParticipants = data["currentParticipants"] as? Int ?? session.currentParticipants
                session.currentBroadcasters = data["currentBroadcasters"] as? Int ?? session.currentBroadcasters
                session.streamMode = data["streamMode"] as? String ?? session.streamMode
                session.durationLimitMinutes = data["durationLimitMinutes"] as? Int ?? session.durationLimitMinutes
                session.hasWaitingRoom = data["hasWaitingRoom"] as? Bool ?? session.hasWaitingRoom
                session.waitingRoomEnabled = data["waitingRoomEnabled"] as? Bool ?? session.waitingRoomEnabled

                if let ts = data["startTime"] as? Timestamp { session.startTime = ts.dateValue() }
                if let ts = data["scheduledStartTime"] as? Timestamp { session.scheduledStartTime = ts.dateValue() }
                if let ts = data["endTime"] as? Timestamp { session.endTime = ts.dateValue() }
                if let ts = data["createdAt"] as? Timestamp { session.createdAt = ts.dateValue() }
                session.thumbnailURL = data["thumbnailURL"] as? String
                session.recordingURL = data["recordingURL"] as? String

                sessions.append(session)
            }

            print("✅ [LIVE SESSION] Fetched \(sessions.count) public sessions from Firebase")
            return sessions
        } catch {
            print("⚠️ [LIVE SESSION] Failed to fetch public sessions: \(error.localizedDescription). If you see an index error, add the composite index in Firebase Console (link in error).")
            return []
        }
    }

    // MARK: - Chat Messages Sync

    /// Sync a chat message to Firebase so other participants see it in real time.
    func syncChatMessage(_ message: ChatMessage) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("⚠️ [FIREBASE] Cannot sync message - Firebase not configured")
            return
        }
        guard let firebaseUserId = getCurrentUserId() else {
            print("⚠️ [FIREBASE] Cannot sync message - user not authenticated with Firebase")
            return
        }
        do {
            let messageRef = db.collection("sessions").document(message.sessionId.uuidString)
                .collection("messages").document(message.id.uuidString)
            let data: [String: Any] = [
                "id": message.id.uuidString,
                "sessionId": message.sessionId.uuidString,
                "userId": firebaseUserId,
                "userName": message.userName,
                "userAvatarURL": message.userAvatarURL ?? NSNull(),
                "message": message.message,
                "timestamp": Timestamp(date: message.timestamp),
                "messageType": message.messageType.rawValue,
                "reactions": message.reactions,
                "mentionedUserIds": message.mentionedUserIds,
                "attachedFileURL": message.attachedFileURL ?? NSNull(),
                "attachedImageURL": message.attachedImageURL ?? NSNull(),
                "voiceMessageURL": message.voiceMessageURL ?? NSNull(),
                "bibleVerseReference": message.bibleVerseReference ?? NSNull(),
                "lastSyncedAt": Timestamp(date: Date())
            ]
            do {
                try await messageRef.setData(data, merge: true)
                print("✅ [FIREBASE] Synced chat message: \(message.id.uuidString) for session: \(message.sessionId)")
            } catch let err {
                print("❌ [FIREBASE] Failed to sync chat message: \(err.localizedDescription)")
            }
        }
        #endif
    }

    /// Start listening for chat messages in a session; call the callback on each new/updated message (call from MainActor; callback is invoked on arbitrary queue).
    func startListeningToChatMessages(sessionId: UUID, onMessageReceived: @escaping (ChatMessage) -> Void) -> ListenerRegistration? {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("⚠️ [FIREBASE] Cannot listen to messages - Firebase not configured")
            return nil
        }
        let messagesRef = db.collection("sessions").document(sessionId.uuidString)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 100)
        let listener = messagesRef.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                if let error = error { print("❌ [FIREBASE] Chat listen error: \(error.localizedDescription)") }
                return
            }
            for change in snapshot.documentChanges where change.type == .added || change.type == .modified {
                if let message = self.createChatMessage(from: change.document.data(), id: change.document.documentID) {
                    onMessageReceived(message)
                }
            }
        }
        print("✅ [FIREBASE] Started listening to chat messages for session: \(sessionId)")
        return listener
        #else
        return nil
        #endif
    }

    /// Call from view onDisappear to stop receiving chat updates.
    func removeChatMessageListener(_ listener: Any?) {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
    }

    // MARK: - Session presentation (Bible study / shared content) sync

    /// Cloud Storage rules require a valid `request.auth` token. Firestore *can* allow writes with `simulator-test-user-shared` without a signed-in user, but Storage will reject uploads.
    #if canImport(FirebaseAuth) && canImport(FirebaseStorage)
    private func ensureFirebaseUserForStorageUpload() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "FirebaseSyncService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not signed in to Firebase. Sign in (e.g. with Apple) to upload to Cloud Storage. Your cover is still saved locally. Simulator: Firestore may work without sign-in, but Storage always requires a signed-in user."]
            )
        }
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            throw NSError(
                domain: "FirebaseSyncService",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not refresh Firebase sign-in. Try signing out and back in, then try again. \(error.localizedDescription)"
                ]
            )
        }
    }
    #endif

    #if canImport(FirebaseStorage)
    /// Extra detail for generic `StorageError error 1` in the console (often 403/HTTP body from GCS, billing, or rules).
    nonisolated static func formatFirebaseStorageError(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["domain=\(ns.domain)", "code=\(ns.code)"]
        if let body = ns.userInfo["ResponseBody"] as? String, !body.isEmpty { parts.append("ResponseBody=\(String(body.prefix(500)))") }
        if let http = ns.userInfo["ResponseErrorCode"] { parts.append("http=\(http)") }
        if let under = ns.userInfo[NSUnderlyingErrorKey] as? NSError { parts.append("underlying=\(under.domain)(\(under.code))") }
        return "\(ns.localizedDescription) — " + parts.joined(separator: " | ")
    }
    #endif

    /// Upload a presentation file (PDF or image) to Storage and return its download URL. Path: sessions/{sessionId}/presentation/{uuid}.{ext}
    func uploadPresentationFile(sessionId: UUID, fileURL: URL, contentType: String) async throws -> String {
        #if canImport(FirebaseStorage)
        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.isEmpty ? (contentType.contains("pdf") ? "pdf" : "jpg") : fileURL.pathExtension
        return try await uploadPresentationData(sessionId: sessionId, data: data, contentType: contentType, fileExtension: ext)
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    /// Upload presentation image data (e.g. from PhotosPicker) and return download URL.
    func uploadPresentationData(sessionId: UUID, data: Data, contentType: String, fileExtension: String) async throws -> String {
        #if canImport(FirebaseStorage)
        #if canImport(FirebaseAuth)
        try await ensureFirebaseUserForStorageUpload()
        #endif
        guard let storage = storage else { throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage not available"]) }
        let path = "sessions/\(sessionId.uuidString)/presentation/\(UUID().uuidString).\(fileExtension)"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    /// Upload local `thumbnailURL` file to Storage and set `session.thumbnailURL` to https (public and private sessions). No-op when already https or missing file.
    func ensureSessionThumbnailOnCloud(session: LiveSession) async {
        #if canImport(FirebaseStorage)
        guard storage != nil, FirebaseInitializer.shared.isConfigured else { return }
        guard let raw = session.thumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        if raw.hasPrefix("https") { return }
        guard let fileURL = Self.resolveLocalThumbnailFileURL(raw) else {
            print("⚠️ [LIVE SESSION] Thumbnail not https and file missing: \(raw.prefix(100))…")
            return
        }
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            print("⚠️ [LIVE SESSION] Could not read thumbnail bytes at \(fileURL.path)")
            return
        }
        do {
            let https = try await uploadLiveSessionThumbnail(sessionId: session.id, imageData: data)
            session.thumbnailURL = https
            try? modelContext?.save()
            print("✅ [LIVE SESSION] Thumbnail uploaded (\(data.count) bytes) → Firestore sync can include thumbnailURL")
        } catch {
            print("⚠️ [LIVE SESSION] ensureSessionThumbnailOnCloud: \(error.localizedDescription)")
        }
        #endif
    }

    /// Resolves a thumbnail string to a readable local file URL (file:// or absolute path).
    private static func resolveLocalThumbnailFileURL(_ thumbnailURLString: String) -> URL? {
        let s = thumbnailURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("https") { return nil }
        if let u = URL(string: s), u.isFileURL, FileManager.default.fileExists(atPath: u.path) { return u }
        if FileManager.default.fileExists(atPath: s) { return URL(fileURLWithPath: s) }
        return nil
    }

    /// Upload live session thumbnail (cover image). Returns download URL.
    func uploadLiveSessionThumbnail(sessionId: UUID, imageData: Data) async throws -> String {
        #if canImport(FirebaseStorage)
        #if canImport(FirebaseAuth)
        try await ensureFirebaseUserForStorageUpload()
        #endif
        guard let storage = storage else { throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage not available"]) }
        let path = "liveSessionThumbnails/\(sessionId.uuidString).jpg"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    /// Save thumbnail URL to a live session (uses configured ModelContext). Call after upload succeeds.
    func saveThumbnailURL(sessionId: UUID, urlString: String) {
        guard let modelContext = modelContext else {
            print("⚠️ [LIVE SESSION] No modelContext configured, cannot save thumbnail URL")
            return
        }
        do {
            var descriptor = FetchDescriptor<LiveSession>()
            descriptor.predicate = #Predicate<LiveSession> { $0.id == sessionId }
            if let session = try modelContext.fetch(descriptor).first {
                session.thumbnailURL = urlString
                try modelContext.save()
                print("✅ [LIVE SESSION] Thumbnail URL saved: \(urlString.prefix(60))...")
                Task { await syncLiveSessionPublic(session) }
            } else {
                print("⚠️ [LIVE SESSION] Session not found for id \(sessionId), cannot save thumbnail URL")
            }
        } catch {
            print("⚠️ [LIVE SESSION] Failed to save thumbnail URL: \(error.localizedDescription)")
        }
    }

    /// Upload a session recording (MP4) to Storage. Use for replay. Path: sessionRecordings/{sessionId}.mp4
    /// Uses putFile for large files to avoid loading into memory.
    func uploadRecording(sessionId: UUID, fileURL: URL) async throws -> String {
        #if canImport(FirebaseStorage)
        #if canImport(FirebaseAuth)
        try await ensureFirebaseUserForStorageUpload()
        #endif
        guard let storage = storage else { throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage not available"]) }
        let path = "sessionRecordings/\(sessionId.uuidString).mp4"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        _ = try await ref.putFileAsync(from: fileURL, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    /// Save recording URL to a live session (local SwiftData + sync to Firestore). Call after upload succeeds.
    func saveRecordingURL(sessionId: UUID, urlString: String) {
        guard let modelContext = modelContext else {
            print("⚠️ [LIVE SESSION] No modelContext configured, cannot save recording URL")
            return
        }
        do {
            var descriptor = FetchDescriptor<LiveSession>()
            descriptor.predicate = #Predicate<LiveSession> { $0.id == sessionId }
            if let session = try modelContext.fetch(descriptor).first {
                session.recordingURL = urlString
                try modelContext.save()
                print("✅ [LIVE SESSION] Recording URL saved for replay")
                Task { await syncLiveSessionPublic(session) }
            } else {
                print("⚠️ [LIVE SESSION] Session not found for id \(sessionId), cannot save recording URL")
            }
        } catch {
            print("⚠️ [LIVE SESSION] Failed to save recording URL: \(error.localizedDescription)")
        }
    }

    /// Set what the host is presenting so participants can see it. type: "bibleStudy", "pdf", "image", or "none". bibleStudyDayOfYear: 1-365 for which topic to show.
    func setSessionPresentation(sessionId: UUID, type: String, pdfURL: String? = nil, imageURL: String? = nil, bibleStudyDayOfYear: Int? = nil) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, getCurrentUserId() != nil else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("presentation").document("current")
        do {
            var data: [String: Any] = ["type": type, "updatedAt": Timestamp(date: Date())]
            if let u = pdfURL { data["pdfURL"] = u }
            if let u = imageURL { data["imageURL"] = u }
            if let day = bibleStudyDayOfYear { data["bibleStudyDayOfYear"] = day }
            try await ref.setData(data, merge: true)
        } catch {
            print("❌ [FIREBASE] setSessionPresentation failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// One-time fetch of current presentation (for participants so they see host's presentation even if listener hasn't fired yet).
    func fetchCurrentSessionPresentation(sessionId: UUID) async -> (type: String?, pdfURL: String?, imageURL: String?, bibleStudyDayOfYear: Int?) {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return (nil, nil, nil, nil) }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("presentation").document("current")
        do {
            let snapshot = try await ref.getDocument()
            guard snapshot.exists, let data = snapshot.data() else { return (nil, nil, nil, nil) }
            let type = data["type"] as? String
            let pdfURL = data["pdfURL"] as? String
            let imageURL = data["imageURL"] as? String
            let bibleStudyDayOfYear = data["bibleStudyDayOfYear"] as? Int
            return (type, pdfURL, imageURL, bibleStudyDayOfYear)
        } catch {
            print("⚠️ [FIREBASE] fetchCurrentSessionPresentation failed: \(error.localizedDescription)")
            return (nil, nil, nil, nil)
        }
        #else
        return (nil, nil, nil, nil)
        #endif
    }

    /// Listen for host's presentation changes. Callback: (type, pdfURL, imageURL, bibleStudyDayOfYear 1-365?).
    func startListeningToSessionPresentation(sessionId: UUID, onUpdate: @escaping (String?, String?, String?, Int?) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("presentation").document("current")
        let listener = ref.addSnapshotListener { snapshot, error in
            if let e = error {
                print("⚠️ [FIREBASE] Presentation listener error: \(e.localizedDescription)")
            }
            let type: String?
            let pdfURL: String?
            let imageURL: String?
            let bibleStudyDayOfYear: Int?
            if let data = snapshot?.data(), snapshot?.exists == true {
                type = data["type"] as? String
                pdfURL = data["pdfURL"] as? String
                imageURL = data["imageURL"] as? String
                bibleStudyDayOfYear = data["bibleStudyDayOfYear"] as? Int
            } else {
                type = nil
                pdfURL = nil
                imageURL = nil
                bibleStudyDayOfYear = nil
            }
            DispatchQueue.main.async { onUpdate(type, pdfURL, imageURL, bibleStudyDayOfYear) }
        }
        return listener
        #else
        return nil
        #endif
    }

    func removePresentationListener(_ listener: Any?) {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
    }

    /// Broadcast host: when `true`, audience clients may call `promoteToPresenter()` to go on camera.
    func setBroadcastOpenFloor(sessionId: UUID, open: Bool) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, getCurrentUserId() != nil else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("liveControls").document("state")
        do {
            try await ref.setData([
                "broadcastOpenFloor": open,
                "updatedAt": Timestamp(date: Date()),
            ], merge: true)
        } catch {
            print("❌ [FIREBASE] setBroadcastOpenFloor failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Listen for host toggling “open floor” (broadcast mode co-presenting).
    func startListeningBroadcastOpenFloor(sessionId: UUID, onUpdate: @escaping (Bool) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("liveControls").document("state")
        let listener = ref.addSnapshotListener { snapshot, error in
            if let e = error {
                print("⚠️ [FIREBASE] broadcastOpenFloor listener: \(e.localizedDescription)")
            }
            let open = (snapshot?.data()?["broadcastOpenFloor"] as? Bool) ?? false
            DispatchQueue.main.async { onUpdate(open) }
        }
        return listener
        #else
        return nil
        #endif
    }

    // MARK: - Host mute participant (sync so participant's app can mute their mic)

    /// Write participant mute state so the participant's client can apply it. Path: sessions/{sessionId}/participants/{userId}
    func updateParticipantMuteState(sessionId: UUID, userId: String, isMuted: Bool) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("participants").document(userId)
        do {
            try await ref.setData(["isMuted": isMuted, "updatedAt": Timestamp(date: Date())], merge: true)
        } catch {
            print("❌ [FIREBASE] updateParticipantMuteState failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Listen for host muting me. Call onMuteChanged with true when host mutes, false when unmuted. Remove listener when leaving stream.
    func startListeningToMyMuteState(sessionId: UUID, myUserId: String, onMuteChanged: @escaping (Bool) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        let ref = db.collection("sessions").document(sessionId.uuidString).collection("participants").document(myUserId)
        let listener = ref.addSnapshotListener { snapshot, _ in
            let isMuted = (snapshot?.data()?["isMuted"] as? Bool) ?? true
            DispatchQueue.main.async { onMuteChanged(isMuted) }
        }
        return listener
        #else
        return nil
        #endif
    }

    func removeMuteStateListener(_ listener: Any?) {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func createChatMessage(from data: [String: Any], id docId: String) -> ChatMessage? {
        Self.createChatMessageFromFirestorePayload(data, documentId: docId, timestampFromTimestamp: { (data["timestamp"] as? Timestamp)?.dateValue() })
    }

    /// Testable: build ChatMessage from Firestore-shaped payload. timestampFromTimestamp can be nil (uses Date()).
    internal static func createChatMessageFromFirestorePayload(
        _ data: [String: Any],
        documentId: String,
        timestampFromTimestamp: (() -> Date?)?
    ) -> ChatMessage? {
        guard let sessionIdString = data["sessionId"] as? String,
              let sessionId = UUID(uuidString: sessionIdString),
              let messageId = UUID(uuidString: documentId) else { return nil }
        let message = ChatMessage(
            sessionId: sessionId,
            userId: data["userId"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            message: data["message"] as? String ?? "",
            messageType: ChatMessage.MessageType(rawValue: data["messageType"] as? String ?? "Text") ?? .text
        )
        message.id = messageId
        message.userAvatarURL = data["userAvatarURL"] as? String
        message.reactions = data["reactions"] as? [String] ?? []
        message.mentionedUserIds = data["mentionedUserIds"] as? [String] ?? []
        message.attachedFileURL = data["attachedFileURL"] as? String
        message.attachedImageURL = data["attachedImageURL"] as? String
        message.voiceMessageURL = data["voiceMessageURL"] as? String
        message.bibleVerseReference = data["bibleVerseReference"] as? String
        if let date = timestampFromTimestamp?() {
            message.timestamp = date
        }
        return message
    }
    #endif

    /// Delete a session invitation from Firebase
    func deleteSessionInvitation(_ invitation: SessionInvitation) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let invitationRef = db.collection("users").document(userId)
                .collection("sessionInvitations").document(invitation.id.uuidString)
            
            try await invitationRef.delete()
            print("✅ [FIREBASE] Deleted session invitation: \(invitation.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete session invitation: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Handle invitation changes from Firebase
    #if canImport(FirebaseFirestore)
    private func handleInvitationChange(_ change: DocumentChange, suppressInviteNotification: Bool = false) {
        guard let modelContext = modelContext else { return }
        
        let data = change.document.data()
        let invitationId = change.document.documentID
        
        switch change.type {
        case .added, .modified:
            // Check if invitation exists locally
            // Convert invitationId string to UUID for comparison
            guard let invitationUUID = UUID(uuidString: invitationId) else {
                print("⚠️ [FIREBASE] Invalid invitation ID format: \(invitationId)")
                return
            }
            let descriptor = FetchDescriptor<SessionInvitation>(
                predicate: #Predicate<SessionInvitation> { $0.id == invitationUUID }
            )
            
            if let existingInvitation = try? modelContext.fetch(descriptor).first {
                // Update existing invitation
                updateLocalInvitation(existingInvitation, with: data)
            } else {
                // Create new invitation
                createLocalInvitation(from: data, id: invitationId)
            }
            
            if change.type == .added && !suppressInviteNotification {
                scheduleSessionInviteLocalNotification(from: data)
            }
            
        case .removed:
            // Delete local invitation
            // Convert invitationId string to UUID for comparison
            guard let invitationUUID = UUID(uuidString: invitationId) else {
                print("⚠️ [FIREBASE] Invalid invitation ID format: \(invitationId)")
                return
            }
            let descriptor = FetchDescriptor<SessionInvitation>(
                predicate: #Predicate<SessionInvitation> { $0.id == invitationUUID }
            )
            if let invitation = try? modelContext.fetch(descriptor).first {
                modelContext.delete(invitation)
                try? modelContext.save()
                print("✅ [FIREBASE] Deleted local invitation: \(invitationId)")
            }
        }
    }
    #else
    private func handleInvitationChange(_ change: Any) {
        // Firebase not available
    }
    #endif
    
    /// Update local invitation with Firebase data
    private func updateLocalInvitation(_ invitation: SessionInvitation, with data: [String: Any]) {
        #if canImport(FirebaseFirestore)
        invitation.sessionTitle = data["sessionTitle"] as? String ?? invitation.sessionTitle
        invitation.hostId = data["hostId"] as? String ?? invitation.hostId
        invitation.hostName = data["hostName"] as? String ?? invitation.hostName
        invitation.invitedUserId = data["invitedUserId"] as? String
        invitation.invitedUserName = data["invitedUserName"] as? String
        invitation.invitedEmail = data["invitedEmail"] as? String
        invitation.inviteCode = data["inviteCode"] as? String ?? invitation.inviteCode
        
        if let statusString = data["status"] as? String,
           let status = SessionInvitation.InvitationStatus(rawValue: statusString) {
            invitation.status = status
        }
        
        if let timestamp = data["respondedAt"] as? Timestamp {
            invitation.respondedAt = timestamp.dateValue()
        }
        
        if let timestamp = data["expiresAt"] as? Timestamp {
            invitation.expiresAt = timestamp.dateValue()
        }
        
        if let sessionIdString = data["sessionId"] as? String,
           let sessionId = UUID(uuidString: sessionIdString) {
            invitation.sessionId = sessionId
        }
        
        try? modelContext?.save()
        print("✅ [FIREBASE] Updated local invitation: \(invitation.id.uuidString)")
        #endif
    }
    
    /// Create local invitation from Firebase data
    private func createLocalInvitation(from data: [String: Any], id: String) {
        #if canImport(FirebaseFirestore)
        guard let modelContext = modelContext,
              let uuid = UUID(uuidString: id),
              let sessionIdString = data["sessionId"] as? String,
              let sessionId = UUID(uuidString: sessionIdString) else {
            print("⚠️ [FIREBASE] Cannot create invitation - invalid UUID")
            return
        }
        
        let invitation = SessionInvitation(
            sessionId: sessionId,
            sessionTitle: data["sessionTitle"] as? String ?? "",
            hostId: data["hostId"] as? String ?? "",
            hostName: data["hostName"] as? String ?? "",
            invitedUserId: data["invitedUserId"] as? String,
            invitedUserName: data["invitedUserName"] as? String,
            invitedEmail: data["invitedEmail"] as? String,
            inviteCode: data["inviteCode"] as? String ?? "",
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue()
        )
        
        invitation.id = uuid
        
        if let statusString = data["status"] as? String,
           let status = SessionInvitation.InvitationStatus(rawValue: statusString) {
            invitation.status = status
        }
        
        if let timestamp = data["createdAt"] as? Timestamp {
            invitation.createdAt = timestamp.dateValue()
        }
        
        if let timestamp = data["respondedAt"] as? Timestamp {
            invitation.respondedAt = timestamp.dateValue()
        }
        
        modelContext.insert(invitation)
        try? modelContext.save()
        print("✅ [FIREBASE] Created local invitation from Firebase: \(id)")
        #endif
    }
    
    /// Local notification when this user receives a new Bible study / live session invite (Firestore → users/.../sessionInvitations).
    private func scheduleSessionInviteLocalNotification(from data: [String: Any]) {
        let pending = SessionInvitation.InvitationStatus.pending.rawValue
        let statusString = data["status"] as? String ?? pending
        guard statusString == pending else { return }
        let sessionTitle = data["sessionTitle"] as? String ?? "Live session"
        let hostName = data["hostName"] as? String ?? "Someone"
        let inviteCode = (data["inviteCode"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inviteCode.isEmpty else { return }
        NotificationService.shared.scheduleSessionInvitationNotification(
            sessionTitle: sessionTitle,
            hostName: hostName,
            inviteCode: inviteCode
        )
    }
    
    // MARK: - Prayer Requests Sync
    
    /// Handle prayer request changes from Firebase
    #if canImport(FirebaseFirestore)
    private func handlePrayerRequestChange(_ change: DocumentChange) {
        guard let modelContext = modelContext else { return }
        
        let data = change.document.data()
        let requestId = change.document.documentID
        
        switch change.type {
        case .added:
            // New prayer request from Firebase - check if it exists locally
            guard let requestUUID = UUID(uuidString: requestId) else {
                print("⚠️ [FIREBASE] Invalid prayer request ID format: \(requestId)")
                return
            }
            let descriptor = FetchDescriptor<PrayerRequest>(
                predicate: #Predicate<PrayerRequest> { $0.id == requestUUID }
            )
            
            if let existingRequest = try? modelContext.fetch(descriptor).first {
                // Request exists locally - check if remote is newer
                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                    if remoteUpdatedAt.dateValue() > existingRequest.updatedAt {
                        print("📥 [FIREBASE] Remote prayer request is newer, updating local")
                        updateLocalPrayerRequest(existingRequest, with: data)
                    } else {
                        print("ℹ️ [FIREBASE] Local prayer request is same or newer, skipping update")
                    }
                } else {
                    print("⚠️ [FIREBASE] Remote prayer request missing updatedAt, updating anyway")
                    updateLocalPrayerRequest(existingRequest, with: data)
                }
            } else {
                // Request doesn't exist locally - create it
                print("➕ [FIREBASE] Creating new local prayer request from Firebase")
                createLocalPrayerRequest(from: data, id: requestId)
            }
            
        case .modified:
            // Prayer request was modified in Firebase - update local if newer
            guard let requestUUID = UUID(uuidString: requestId) else {
                print("⚠️ [FIREBASE] Invalid prayer request ID format: \(requestId)")
                return
            }
            let descriptor = FetchDescriptor<PrayerRequest>(
                predicate: #Predicate<PrayerRequest> { $0.id == requestUUID }
            )
            
            if let existingRequest = try? modelContext.fetch(descriptor).first {
                // Check if remote is newer
                if let remoteUpdatedAt = data["updatedAt"] as? Timestamp {
                    if remoteUpdatedAt.dateValue() > existingRequest.updatedAt {
                        print("📥 [FIREBASE] Remote prayer request modified and is newer, updating local")
                        updateLocalPrayerRequest(existingRequest, with: data)
                    } else {
                        print("ℹ️ [FIREBASE] Local prayer request is newer, skipping remote update")
                    }
                } else {
                    print("📥 [FIREBASE] Remote prayer request modified (no updatedAt), updating local")
                    updateLocalPrayerRequest(existingRequest, with: data)
                }
            } else {
                // Request was modified but doesn't exist locally - create it
                print("➕ [FIREBASE] Modified prayer request doesn't exist locally, creating it")
                createLocalPrayerRequest(from: data, id: requestId)
            }
            
        case .removed:
            // Prayer request was deleted in Firebase - delete local
            print("🗑️ [FIREBASE] Prayer request deleted in Firebase, removing local")
            guard let requestUUID = UUID(uuidString: requestId) else {
                print("⚠️ [FIREBASE] Invalid prayer request ID format: \(requestId)")
                return
            }
            let descriptor = FetchDescriptor<PrayerRequest>(
                predicate: #Predicate<PrayerRequest> { $0.id == requestUUID }
            )
            if let request = try? modelContext.fetch(descriptor).first {
                modelContext.delete(request)
                do {
                    try modelContext.save()
                    print("✅ [FIREBASE] Deleted local prayer request: \(requestId)")
                } catch {
                    print("❌ [FIREBASE] Failed to save deletion: \(error.localizedDescription)")
                }
            } else {
                print("ℹ️ [FIREBASE] Prayer request to delete not found locally: \(requestId)")
            }
        }
    }
    #endif
    
    /// Update local prayer request with Firebase data
    private func updateLocalPrayerRequest(_ request: PrayerRequest, with data: [String: Any]) {
        #if canImport(FirebaseFirestore)
        request.title = data["title"] as? String ?? request.title
        request.details = data["details"] as? String ?? request.details
        
        if let timestamp = data["date"] as? Timestamp {
            request.date = timestamp.dateValue()
        }
        
        if let statusString = data["status"] as? String,
           let status = PrayerRequest.PrayerStatus(rawValue: statusString) {
            request.status = status
        }
        
        request.isAnswered = data["isAnswered"] as? Bool ?? request.isAnswered
        
        if let answerDate = data["answerDate"] as? Timestamp {
            request.answerDate = answerDate.dateValue()
        } else if data["answerDate"] is NSNull {
            request.answerDate = nil
        }
        
        request.answerNotes = data["answerNotes"] as? String
        
        request.isPrivate = data["isPrivate"] as? Bool ?? request.isPrivate
        request.tags = data["tags"] as? [String] ?? request.tags
        request.prayerPartners = data["prayerPartners"] as? [String] ?? request.prayerPartners
        request.enableReminder = data["enableReminder"] as? Bool ?? request.enableReminder
        
        if let reminderTime = data["reminderTime"] as? Timestamp {
            request.reminderTime = reminderTime.dateValue()
        }
        
        request.reminderFrequency = data["reminderFrequency"] as? String ?? request.reminderFrequency
        
        if let timestamp = data["createdAt"] as? Timestamp {
            request.createdAt = timestamp.dateValue()
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            request.updatedAt = timestamp.dateValue()
        }
        
        try? modelContext?.save()
        print("✅ [FIREBASE] Updated local prayer request: \(request.id.uuidString)")
        #endif
    }
    
    /// Create local prayer request from Firebase data
    private func createLocalPrayerRequest(from data: [String: Any], id: String) {
        #if canImport(FirebaseFirestore)
        guard let modelContext = modelContext,
              let uuid = UUID(uuidString: id) else {
            print("⚠️ [FIREBASE] Cannot create prayer request - invalid UUID")
            return
        }
        
        let request = PrayerRequest(
            title: data["title"] as? String ?? "",
            details: data["details"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            isPrivate: data["isPrivate"] as? Bool ?? false
        )
        
        request.id = uuid
        
        if let timestamp = data["date"] as? Timestamp {
            request.date = timestamp.dateValue()
        }
        
        if let statusString = data["status"] as? String,
           let status = PrayerRequest.PrayerStatus(rawValue: statusString) {
            request.status = status
        }
        
        request.isAnswered = data["isAnswered"] as? Bool ?? false
        
        if let answerDate = data["answerDate"] as? Timestamp {
            request.answerDate = answerDate.dateValue()
        }
        
        request.answerNotes = data["answerNotes"] as? String
        request.prayerPartners = data["prayerPartners"] as? [String] ?? []
        request.enableReminder = data["enableReminder"] as? Bool ?? false
        
        if let reminderTime = data["reminderTime"] as? Timestamp {
            request.reminderTime = reminderTime.dateValue()
        }
        
        request.reminderFrequency = data["reminderFrequency"] as? String ?? ""
        
        if let timestamp = data["createdAt"] as? Timestamp {
            request.createdAt = timestamp.dateValue()
        } else {
            request.createdAt = Date()
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            request.updatedAt = timestamp.dateValue()
        } else {
            request.updatedAt = Date()
        }
        
        modelContext.insert(request)
        try? modelContext.save()
        print("✅ [FIREBASE] Created local prayer request from Firebase: \(id)")
        #endif
    }
    
    func syncPrayerRequest(_ request: PrayerRequest) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let requestRef = db.collection("users").document(userId)
                .collection("prayerRequests").document(request.id.uuidString)
            
            let data: [String: Any] = [
                "id": request.id.uuidString,
                "title": request.title,
                "details": request.details,
                "date": Timestamp(date: request.date),
                "status": request.status.rawValue,
                "isAnswered": request.isAnswered,
                "answerDate": request.answerDate.map { Timestamp(date: $0) } ?? NSNull(),
                "answerNotes": request.answerNotes ?? NSNull(),
                "isPrivate": request.isPrivate,
                "tags": request.tags,
                "prayerPartners": request.prayerPartners,
                "enableReminder": request.enableReminder,
                "reminderTime": Timestamp(date: request.reminderTime),
                "reminderFrequency": request.reminderFrequency,
                "isSharedWithFriends": request.isSharedWithFriends,
                "intercessorIds": request.intercessorIds,
                "createdAt": Timestamp(date: request.createdAt),
                "updatedAt": Timestamp(date: request.updatedAt)
            ]

            try await requestRef.setData(data, merge: true)

            // Mirror to sharedPrayers so friends can read it; delete if un-shared or private
            let sharedRef = db.collection("users").document(userId)
                .collection("sharedPrayers").document(request.id.uuidString)
            if request.isSharedWithFriends && !request.isPrivate {
                try await sharedRef.setData(data, merge: true)
            } else {
                try? await sharedRef.delete()
            }

            print("✅ [FIREBASE] Synced prayer request: \(request.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync prayer request: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Delete a prayer request from Firebase
    func deletePrayerRequest(_ request: PrayerRequest) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let requestRef = db.collection("users").document(userId)
                .collection("prayerRequests").document(request.id.uuidString)
            
            try await requestRef.delete()
            print("✅ [FIREBASE] Deleted prayer request: \(request.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete prayer request: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Mood Entries Sync
    
    func syncMoodEntry(_ entry: MoodEntry) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let entryRef = db.collection("users").document(userId)
                .collection("moodEntries").document(entry.id.uuidString)
            
            var data: [String: Any] = [
                "id": entry.id.uuidString,
                "mood": entry.mood,
                "intensity": entry.intensity,
                "date": Timestamp(date: entry.date),
                "tags": entry.tags,
                "moodCategory": entry.moodCategory,
                "emoji": entry.emoji,
                "timeOfDay": entry.timeOfDay,
                "activities": entry.activities,
                "energyLevel": entry.energyLevel,
                "triggers": entry.triggers,
                "createdAt": Timestamp(date: entry.createdAt)
            ]
            
            if let notes = entry.notes {
                data["notes"] = notes
            }
            if let location = entry.location {
                data["location"] = location
            }
            if let latitude = entry.latitude {
                data["latitude"] = latitude
            }
            if let longitude = entry.longitude {
                data["longitude"] = longitude
            }
            if let weather = entry.weather {
                data["weather"] = weather
            }
            if let temperature = entry.temperature {
                data["temperature"] = temperature
            }
            if let sleepQuality = entry.sleepQuality {
                data["sleepQuality"] = sleepQuality
            }
            if let linkedJournalEntryId = entry.linkedJournalEntryId {
                data["linkedJournalEntryId"] = linkedJournalEntryId.uuidString
            }
            if let linkedReadingPlanId = entry.linkedReadingPlanId {
                data["linkedReadingPlanId"] = linkedReadingPlanId.uuidString
            }
            if !entry.linkedPrayerRequestIds.isEmpty {
                data["linkedPrayerRequestIds"] = entry.linkedPrayerRequestIds.map { $0.uuidString }
            }
            if let photoURL = entry.photoURL {
                data["photoURL"] = photoURL.absoluteString
            }
            if let voiceNoteURL = entry.voiceNoteURL {
                data["voiceNoteURL"] = voiceNoteURL.absoluteString
            }
            
            try await entryRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced mood entry: \(entry.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync mood entry: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Bookmarked Verses Sync
    
    func syncBookmarkedVerse(_ verse: BookmarkedVerse) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let verseRef = db.collection("users").document(userId)
                .collection("bookmarkedVerses").document(verse.id.uuidString)
            
            var data: [String: Any] = [
                "id": verse.id.uuidString,
                "verseReference": verse.verseReference,
                "verseText": verse.verseText,
                "translation": verse.translation,
                "notes": verse.notes,
                "createdAt": Timestamp(date: verse.createdAt)
            ]
            
            if let sessionId = verse.sessionId {
                data["sessionId"] = sessionId.uuidString
            }
            if !verse.sessionTitle.isEmpty {
                data["sessionTitle"] = verse.sessionTitle
            }
            if !verse.bookmarkedBy.isEmpty {
                data["bookmarkedBy"] = verse.bookmarkedBy
            }
            if !verse.bookmarkedByName.isEmpty {
                data["bookmarkedByName"] = verse.bookmarkedByName
            }
            
            try await verseRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced bookmarked verse: \(verse.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync bookmarked verse: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Delete a bookmarked verse from Firebase
    func deleteBookmarkedVerse(_ verse: BookmarkedVerse) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let verseRef = db.collection("users").document(userId)
                .collection("bookmarkedVerses").document(verse.id.uuidString)
            
            try await verseRef.delete()
            print("✅ [FIREBASE] Deleted bookmarked verse: \(verse.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete bookmarked verse: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Bible Highlights Sync
    
    func syncBibleHighlight(_ highlight: BibleHighlight) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let highlightRef = db.collection("users").document(userId)
                .collection("bibleHighlights").document(highlight.id.uuidString)
            
            let data: [String: Any] = [
                "id": highlight.id.uuidString,
                "verseReference": highlight.verseReference,
                "verseText": highlight.verseText,
                "translation": highlight.translation,
                "colorIndex": highlight.colorIndex,
                "createdAt": Timestamp(date: highlight.createdAt)
            ]
            
            try await highlightRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced Bible highlight: \(highlight.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync Bible highlight: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Delete a Bible highlight from Firebase
    func deleteBibleHighlight(_ highlight: BibleHighlight) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let highlightRef = db.collection("users").document(userId)
                .collection("bibleHighlights").document(highlight.id.uuidString)
            
            try await highlightRef.delete()
            print("✅ [FIREBASE] Deleted Bible highlight: \(highlight.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete Bible highlight: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Bible Notes Sync
    
    func syncBibleNote(_ note: BibleNote) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let noteRef = db.collection("users").document(userId)
                .collection("bibleNotes").document(note.id.uuidString)
            
            let data: [String: Any] = [
                "id": note.id.uuidString,
                "verseReference": note.verseReference,
                "verseText": note.verseText,
                "translation": note.translation,
                "noteText": note.noteText,
                "createdAt": Timestamp(date: note.createdAt),
                "updatedAt": Timestamp(date: note.updatedAt)
            ]
            
            try await noteRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced Bible note: \(note.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync Bible note: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Delete a Bible note from Firebase
    func deleteBibleNote(_ note: BibleNote) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let noteRef = db.collection("users").document(userId)
                .collection("bibleNotes").document(note.id.uuidString)
            
            try await noteRef.delete()
            print("✅ [FIREBASE] Deleted Bible note: \(note.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to delete Bible note: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Reading Plans Sync
    
    func syncReadingPlan(_ plan: ReadingPlan) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        
        do {
            let planRef = db.collection("users").document(userId)
                .collection("readingPlans").document(plan.id.uuidString)
            
            // Encode readings array to JSON string
            let readingsJSON: String
            if let readingsData = plan.readingsData,
               let jsonString = String(data: readingsData, encoding: .utf8) {
                readingsJSON = jsonString
            } else {
                // Fallback: encode readings array
                if let encoded = try? JSONEncoder().encode(plan.readings) {
                    readingsJSON = String(data: encoded, encoding: .utf8) ?? "[]"
                } else {
                    readingsJSON = "[]"
                }
            }
            
            // Encode notes array to JSON string if available
            let notesJSON: String
            if let notesData = plan.notesData,
               let jsonString = String(data: notesData, encoding: .utf8) {
                notesJSON = jsonString
            } else {
                notesJSON = "[]"
            }
            
            var data: [String: Any] = [
                "id": plan.id.uuidString,
                "title": plan.title,
                "planDescription": plan.planDescription,
                "duration": plan.duration,
                "startDate": Timestamp(date: plan.startDate),
                "currentDay": plan.currentDay,
                "isCompleted": plan.isCompleted,
                "readingsData": readingsJSON,
                "reminderEnabled": plan.reminderEnabled,
                "reminderTime": Timestamp(date: plan.reminderTime),
                "catchUpModeEnabled": plan.catchUpModeEnabled,
                "isPaused": plan.isPaused,
                "streakCount": plan.streakCount,
                "longestStreak": plan.longestStreak,
                "totalReadingTime": plan.totalReadingTime,
                "category": plan.category,
                "difficulty": plan.difficulty,
                "isCustom": plan.isCustom,
                "sharedWithFriends": plan.sharedWithFriends,
                "notesData": notesJSON,
                "createdAt": Timestamp(date: plan.createdAt)
            ]
            
            if let endDate = plan.endDate {
                data["endDate"] = Timestamp(date: endDate)
            }
            if let pauseDate = plan.pauseDate {
                data["pauseDate"] = Timestamp(date: pauseDate)
            }
            if let lastReadingDate = plan.lastReadingDate {
                data["lastReadingDate"] = Timestamp(date: lastReadingDate)
            }
            
            try await planRef.setData(data, merge: true)
            print("✅ [FIREBASE] Synced reading plan: \(plan.id.uuidString)")
        } catch {
            print("❌ [FIREBASE] Failed to sync reading plan: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Full Sync
    
    /// Call if sync status is stuck on "Syncing..." so the UI can show "Ready" again. Safe to call anytime.
    func clearStuckSyncState() {
        isSyncing = false
    }
    
    /// Sync all local data to Firebase
    func syncAllData() async {
        #if canImport(FirebaseFirestore)
        guard let modelContext = modelContext else {
            print("⚠️ [FIREBASE] Cannot sync - modelContext not set")
            return
        }
        
        var userId = getCurrentUserId()
        if userId == nil {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            userId = getCurrentUserId()
        }
        guard let userId = userId else {
            print("❌ [FIREBASE] Cannot sync - user not authenticated")
            print("❌ [FIREBASE] User must sign in with Apple for sync to work")
            syncError = "User not authenticated. Please sign in with Apple."
            return
        }
        
        // Skip if a full sync is already in progress (avoids multiple overlapping syncs and repeated timeouts)
        guard !isSyncing else {
            print("ℹ️ [FIREBASE] Full sync already in progress - skipping")
            return
        }
        
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        
        // Safety: if sync hangs (e.g. network), clear isSyncing so UI doesn't stay stuck on "Syncing..."
        let timeoutSeconds: UInt64 = 90
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    isSyncing = false
                    syncError = "Sync timed out - try again or check Wi‑Fi"
                }
                print("⚠️ [FIREBASE] Sync timed out after \(timeoutSeconds)s - check network")
            }
        }
        defer { timeoutTask.cancel() }
        
        print("🔄 [FIREBASE] Starting full sync for user: \(userId)")
        
        var syncedCount = 0
        var errorCount = 0
        
        // Sync journal entries
        let journalDescriptor = FetchDescriptor<JournalEntry>()
        if let entries = try? modelContext.fetch(journalDescriptor) {
            print("📝 [FIREBASE] Syncing \(entries.count) journal entries...")
            for entry in entries {
                await syncJournalEntry(entry, updateSyncState: false)
                if syncError == nil {
                    syncedCount += 1
                } else {
                    errorCount += 1
                    print("⚠️ [FIREBASE] Failed to sync entry: \(entry.id)")
                }
            }
            print("✅ [FIREBASE] Synced \(syncedCount) journal entries, \(errorCount) errors")
        }
        
        // Sync prayer requests
        let prayerDescriptor = FetchDescriptor<PrayerRequest>()
        if let requests = try? modelContext.fetch(prayerDescriptor) {
            print("🙏 [FIREBASE] Syncing \(requests.count) prayer requests...")
            syncedCount = 0
            errorCount = 0
            for request in requests {
                await syncPrayerRequest(request)
                if syncError == nil {
                    syncedCount += 1
                } else {
                    errorCount += 1
                }
            }
            print("✅ [FIREBASE] Synced \(syncedCount) prayer requests, \(errorCount) errors")
        }
        
        // Sync mood entries
        let moodDescriptor = FetchDescriptor<MoodEntry>()
        if let moodEntries = try? modelContext.fetch(moodDescriptor) {
            print("😊 [FIREBASE] Syncing \(moodEntries.count) mood entries...")
            for entry in moodEntries {
                await syncMoodEntry(entry)
            }
        }
        
        // Sync bookmarked verses
        let bookmarkDescriptor = FetchDescriptor<BookmarkedVerse>()
        if let bookmarks = try? modelContext.fetch(bookmarkDescriptor) {
            print("🔖 [FIREBASE] Syncing \(bookmarks.count) bookmarked verses...")
            for bookmark in bookmarks {
                await syncBookmarkedVerse(bookmark)
            }
        }
        
        // Sync Bible highlights
        let highlightDescriptor = FetchDescriptor<BibleHighlight>()
        if let highlights = try? modelContext.fetch(highlightDescriptor) {
            print("✏️ [FIREBASE] Syncing \(highlights.count) Bible highlights...")
            for highlight in highlights {
                await syncBibleHighlight(highlight)
            }
        }
        
        // Sync Bible notes
        let noteDescriptor = FetchDescriptor<BibleNote>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            print("📝 [FIREBASE] Syncing \(notes.count) Bible notes...")
            for note in notes {
                await syncBibleNote(note)
            }
        }
        
        // Sync reading plans
        let readingPlanDescriptor = FetchDescriptor<ReadingPlan>()
        if let plans = try? modelContext.fetch(readingPlanDescriptor) {
            print("📖 [FIREBASE] Syncing \(plans.count) reading plans...")
            for plan in plans {
                await syncReadingPlan(plan)
            }
        }
        
        // Sync session invitations
        let invitationDescriptor = FetchDescriptor<SessionInvitation>()
        if let invitations = try? modelContext.fetch(invitationDescriptor) {
            print("📨 [FIREBASE] Syncing \(invitations.count) session invitations...")
            for invitation in invitations {
                await syncSessionInvitation(invitation)
            }
        }
        
        lastSyncDate = Date()
        syncError = nil  // Clear so Settings shows "Synced" not a previous error
        
        if errorCount > 0 {
            print("⚠️ [FIREBASE] Full sync completed with \(errorCount) errors")
        } else {
            print("✅ [FIREBASE] Full sync completed successfully")
        }
        #else
        print("⚠️ [FIREBASE] Firebase not available - cannot sync")
        #endif
    }
    
    // MARK: - Faith Friends
    
    /// Internal: awaitable upsert + friend code creation.
    private func performUpsertAndEnsureFriendCode(userId: String, displayName: String, email: String? = nil, avatarURL: String? = nil) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let nameLower = name.lowercased()
        let tokens = nameLower.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let emailTrimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasEmail = emailTrimmed.map { !$0.isEmpty } ?? false
        do {
            let ref = db.collection("userSearchProfiles").document(userId)
            var data: [String: Any] = [
                "userId": userId,
                "displayName": name,
                "displayNameLower": nameLower,
                "avatarURL": avatarURL ?? NSNull(),
                "updatedAt": Timestamp(date: Date())
            ]
            if !tokens.isEmpty { data["searchTokens"] = tokens }
            if hasEmail, let em = emailTrimmed { data["emailLower"] = em }
            try await ref.setData(data, merge: true)
            await ensureFriendCode(userId: userId, displayName: name)
            print("✅ [FAITH FRIENDS] Upserted user search profile for \(userId)")
        } catch {
            print("⚠️ [FAITH FRIENDS] Failed to upsert search profile: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Upsert user search profile for in-app search (called when user saves profile).
    func upsertUserSearchProfile(userId: String, displayName: String, email: String? = nil, avatarURL: String? = nil) {
        Task { await performUpsertAndEnsureFriendCode(userId: userId, displayName: displayName, email: email, avatarURL: avatarURL) }
    }
    
    /// Call from Faith Friends screen to ensure current user is in search index.
    func refreshMySearchProfile() {
        Task { await ensureCurrentUserInSearchProfiles() }
    }
    
    /// Ensure current user is in userSearchProfiles. Tries users/ doc first, then local UserProfile.
    /// Many users have Firebase data but users/{userId} has no "name" (created implicitly by subcollections).
    private func ensureCurrentUserInSearchProfiles() async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        var name: String?
        var email: String?
        var avatarURL: String?
        // 1. Try users/ document
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let data = doc.data() {
                name = data["name"] as? String
                email = data["email"] as? String
                avatarURL = data["profileImageURL"] as? String
            }
        } catch { /* users/ doc may not exist */ }
        // 2. Fallback: local UserProfile (SwiftData) - users often have name locally but never saved to Firestore
        if (name == nil || name!.isEmpty), let ctx = modelContext {
            let descriptor = FetchDescriptor<UserProfile>()
            if let profile = try? ctx.fetch(descriptor).first, !profile.name.isEmpty {
                name = profile.name
                if email == nil { email = profile.email }
                if avatarURL == nil { avatarURL = profile.avatarPhotoURL }
                // Persist to users/ so future loads have it
                let nameLower = profile.name.lowercased()
                var data: [String: Any] = [
                    "name": profile.name,
                    "nameLower": nameLower,
                    "updatedAt": Timestamp(date: Date())
                ]
                if let e = profile.email, !e.isEmpty {
                    data["email"] = e
                    data["emailLower"] = e.lowercased()
                }
                try? await db.collection("users").document(userId).setData(data, merge: true)
                print("✅ [FAITH FRIENDS] Synced local UserProfile to Firestore and search index for \(userId)")
            }
        }
        // 3. Auth fallbacks for email and name
        #if canImport(FirebaseAuth)
        if let authUser = Auth.auth().currentUser {
            if email == nil || email!.isEmpty { email = authUser.email }
            if (name == nil || name!.isEmpty), let authName = authUser.displayName, !authName.isEmpty {
                name = authName
            }
        }
        #endif
        let displayName: String
        if let n = name, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = n.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            displayName = "Friend"
            print("⚠️ [FAITH FRIENDS] No name for user \(userId) - using fallback for friend code. Set name in Profile to update.")
        }
        await performUpsertAndEnsureFriendCode(userId: userId, displayName: displayName, email: email, avatarURL: avatarURL)
        print("✅ [FAITH FRIENDS] Added user to search index: \(displayName)")
        #endif
    }
    
    /// Search users by display name (prefix + any word in name).
    /// Prefix finds "John" when typing "jo"; searchTokens finds "John Smith" when typing "smith".
    func searchUsers(query: String, limit: Int = 20) async -> [[String: Any]] {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        
        do {
            var seenIds = Set<String>()
            var results: [[String: Any]] = []
            
            // 1. Prefix search (displayNameLower starts with query)
            let start = q
            let end = q + "\u{f8ff}"
            var prefixCount = 0
            let snap = try await db.collection("userSearchProfiles")
                .whereField("displayNameLower", isGreaterThanOrEqualTo: start)
                .whereField("displayNameLower", isLessThanOrEqualTo: end)
                .limit(to: limit)
                .getDocuments()
            prefixCount = snap.documents.count
            for doc in snap.documents {
                guard !seenIds.contains(doc.documentID) else { continue }
                seenIds.insert(doc.documentID)
                var data = doc.data()
                data["userId"] = doc.documentID
                results.append(data)
            }
            
            // 2. Token search (any word in name matches) - finds "John Smith" when typing "smith"
            var tokenCount = 0
            if results.count < limit {
                let tokenSnap = try await db.collection("userSearchProfiles")
                    .whereField("searchTokens", arrayContains: q)
                    .limit(to: limit)
                    .getDocuments()
                tokenCount = tokenSnap.documents.count
                for doc in tokenSnap.documents {
                    guard !seenIds.contains(doc.documentID) else { continue }
                    seenIds.insert(doc.documentID)
                    var data = doc.data()
                    data["userId"] = doc.documentID
                    results.append(data)
                    if results.count >= limit { break }
                }
            }
            
            // 3. Email prefix search - finds users when typing email (e.g. "john@")
            var emailPrefixCount = 0
            if results.count < limit {
                let emailStart = q
                let emailEnd = q + "\u{f8ff}"
                let emailSnap = try await db.collection("userSearchProfiles")
                    .whereField("emailLower", isGreaterThanOrEqualTo: emailStart)
                    .whereField("emailLower", isLessThanOrEqualTo: emailEnd)
                    .limit(to: limit)
                    .getDocuments()
                emailPrefixCount = emailSnap.documents.count
                for doc in emailSnap.documents {
                    guard !seenIds.contains(doc.documentID) else { continue }
                    seenIds.insert(doc.documentID)
                    var data = doc.data()
                    data["userId"] = doc.documentID
                    results.append(data)
                    if results.count >= limit { break }
                }
            }
            
            // 4. Users collection - find users who have nameLower/email in Firebase but may not be in userSearchProfiles
            var usersNameCount = 0
            var usersEmailCount = 0
            if results.count < limit {
                let usersNameSnap = try? await db.collection("users")
                    .whereField("nameLower", isGreaterThanOrEqualTo: start)
                    .whereField("nameLower", isLessThanOrEqualTo: end)
                    .limit(to: limit)
                    .getDocuments()
                usersNameCount = usersNameSnap?.documents.count ?? 0
                for doc in usersNameSnap?.documents ?? [] {
                    guard !seenIds.contains(doc.documentID) else { continue }
                    let data = doc.data()
                    guard let name = data["name"] as? String, !name.isEmpty else { continue }
                    seenIds.insert(doc.documentID)
                    var out: [String: Any] = [
                        "userId": doc.documentID,
                        "displayName": name,
                        "displayNameLower": (data["nameLower"] as? String) ?? name.lowercased()
                    ]
                    if let email = data["email"] as? String { out["emailLower"] = email.lowercased() }
                    if let avatar = data["profileImageURL"] as? String { out["avatarURL"] = avatar }
                    results.append(out)
                    if results.count >= limit { break }
                }
            }
            if results.count < limit {
                let usersEmailSnap = try? await db.collection("users")
                    .whereField("emailLower", isGreaterThanOrEqualTo: start)
                    .whereField("emailLower", isLessThanOrEqualTo: end)
                    .limit(to: limit)
                    .getDocuments()
                usersEmailCount = usersEmailSnap?.documents.count ?? 0
                for doc in usersEmailSnap?.documents ?? [] {
                    guard !seenIds.contains(doc.documentID) else { continue }
                    let data = doc.data()
                    guard let name = data["name"] as? String, !name.isEmpty else { continue }
                    seenIds.insert(doc.documentID)
                    var out: [String: Any] = [
                        "userId": doc.documentID,
                        "displayName": name,
                        "displayNameLower": (data["nameLower"] as? String) ?? name.lowercased()
                    ]
                    if let email = data["email"] as? String { out["emailLower"] = email.lowercased() }
                    if let avatar = data["profileImageURL"] as? String { out["avatarURL"] = avatar }
                    results.append(out)
                    if results.count >= limit { break }
                }
            }
            
            var final = Array(results.prefix(limit))

            // 5. Fallback: fetch recent profiles and filter client-side (helps when indexes/builds are stale or collection is small)
            if final.isEmpty {
                let fallbackSnap = try? await db.collection("userSearchProfiles").limit(to: 50).getDocuments()
                for doc in fallbackSnap?.documents ?? [] {
                    guard !seenIds.contains(doc.documentID) else { continue }
                    let data = doc.data()
                    let displayNameLower = (data["displayNameLower"] as? String) ?? ""
                    let tokens = data["searchTokens"] as? [String] ?? []
                    let emailLower = data["emailLower"] as? String ?? ""
                    // Match: name contains query, token starts-with/contains query, or email contains query.
                    // Avoid q.contains($0) - would match self when typing "ronell@work.com" (query contains name "ronell")
                    let matches = displayNameLower.contains(q) ||
                        tokens.contains { $0.contains(q) } ||
                        emailLower.contains(q)
                    if matches, let name = data["displayName"] as? String, !name.isEmpty {
                        seenIds.insert(doc.documentID)
                        var out = data
                        out["userId"] = doc.documentID
                        final.append(out)
                        if final.count >= limit { break }
                    }
                }
                if !final.isEmpty {
                    print("ℹ️ [FAITH FRIENDS] Fallback client-side filter found \(final.count) users")
                }
            }

            print("ℹ️ [FAITH FRIENDS] Search \"\(q)\": prefix=\(prefixCount) token=\(tokenCount) email=\(emailPrefixCount) usersName=\(usersNameCount) usersEmail=\(usersEmailCount) fallback=\(final.count) → total=\(final.count)")
            if final.isEmpty {
                print("ℹ️ [FAITH FRIENDS] No users found. Have others: 1) Opened the app, 2) Saved their name in Profile (More → Profile → Edit)?")
            }
            return final
        } catch {
            print("⚠️ [FAITH FRIENDS] Search failed: \(error.localizedDescription)")
            print("⚠️ [FAITH FRIENDS] Query was: \(q). Error: \((error as NSError).localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    /// Create unique friend document ID (sorted for consistency).
    private func friendDocId(_ a: String, _ b: String) -> String {
        if a < b { return "\(a)_\(b)" }
        return "\(b)_\(a)"
    }
    
    // MARK: - Friend Codes (share code to receive friend requests, like invites)
    
    private static let friendCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    
    private func generateFriendCode() -> String {
        let chars = Self.friendCodeChars
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    /// Ensures the user has a friend code in friendCodes/ and userSearchProfiles. Called from upsertUserSearchProfile.
    private func ensureFriendCode(userId: String, displayName: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        do {
            let profileRef = db.collection("userSearchProfiles").document(userId)
            let snap = try await profileRef.getDocument()
            let existing = snap.data()?["friendCode"] as? String
            if let code = existing, !code.isEmpty {
                let codeRef = db.collection("friendCodes").document(code)
                let codeSnap = try await codeRef.getDocument()
                if codeSnap.exists, (codeSnap.data()?["userId"] as? String) == userId { return }
            }
            var code = generateFriendCode()
            for _ in 0..<5 {
                let codeRef = db.collection("friendCodes").document(code)
                let codeSnap = try await codeRef.getDocument()
                if !codeSnap.exists {
                    try await codeRef.setData([
                        "userId": userId,
                        "displayName": displayName,
                        "createdAt": Timestamp(date: Date())
                    ])
                    try await profileRef.setData(["friendCode": code], merge: true)
                    print("✅ [FAITH FRIENDS] Created friend code \(code) for \(userId)")
                    return
                }
                if (codeSnap.data()?["userId"] as? String) == userId {
                    try await profileRef.setData(["friendCode": code], merge: true)
                    return
                }
                code = generateFriendCode()
            }
            print("⚠️ [FAITH FRIENDS] Could not create friend code for \(userId) (collisions)")
        } catch {
            print("⚠️ [FAITH FRIENDS] ensureFriendCode failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Called on sign-in to create friend code immediately so it's ready before user opens Faith Friends.
    func ensureFriendCodeOnSignIn() async {
        if await getMyFriendCode() != nil { return }
        await createMinimalFriendCodeIfNeeded()
    }
    
    /// Ensures profile + friend code exist, then returns the code. Use this from Faith Friends so the code is ready before display.
    func ensureAndGetMyFriendCode() async -> String? {
        if let existing = await getMyFriendCode() { return existing }
        await createMinimalFriendCodeIfNeeded()
        if let code = await getMyFriendCode() { return code }
        await ensureCurrentUserInSearchProfiles()
        return await getMyFriendCode()
    }
    
    /// Fallback: create friend code with minimal data (no profile/name required). Used when ensure flow fails.
    private func createMinimalFriendCodeIfNeeded() async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return }
        do {
            let profileRef = db.collection("userSearchProfiles").document(userId)
            let snap = try await profileRef.getDocument()
            if let existing = snap.data()?["friendCode"] as? String, !existing.isEmpty { return }
            var code = generateFriendCode()
            for _ in 0..<5 {
                let codeRef = db.collection("friendCodes").document(code)
                let codeSnap = try await codeRef.getDocument()
                if !codeSnap.exists {
                    try await codeRef.setData([
                        "userId": userId,
                        "displayName": "Friend",
                        "createdAt": Timestamp(date: Date())
                    ])
                    try await profileRef.setData([
                        "userId": userId,
                        "displayName": "Friend",
                        "displayNameLower": "friend",
                        "friendCode": code,
                        "updatedAt": Timestamp(date: Date())
                    ], merge: true)
                    print("✅ [FAITH FRIENDS] Created minimal friend code \(code) for \(userId)")
                    return
                }
                if (codeSnap.data()?["userId"] as? String) == userId {
                    try await profileRef.setData(["friendCode": code], merge: true)
                    return
                }
                code = generateFriendCode()
            }
        } catch {
            print("⚠️ [FAITH FRIENDS] createMinimalFriendCode failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Returns current user's friend code, or nil if not yet created.
    func getMyFriendCode() async -> String? {
        #if canImport(FirebaseFirestore)
        guard let db = db, let userId = getCurrentUserId() else { return nil }
        do {
            let snap = try await db.collection("userSearchProfiles").document(userId).getDocument()
            return snap.data()?["friendCode"] as? String
        } catch { return nil }
        #else
        return nil
        #endif
    }
    
    /// Lookup user by friend code. Returns (userId, displayName) or nil.
    func lookupUserByFriendCode(_ code: String) async -> (userId: String, displayName: String)? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard c.count == 6 else { return nil }
        do {
            let snap = try await db.collection("friendCodes").document(c).getDocument()
            guard snap.exists, let data = snap.data(),
                  let uid = data["userId"] as? String,
                  let name = data["displayName"] as? String, !name.isEmpty else { return nil }
            return (uid, name)
        } catch { return nil }
        #else
        return nil
        #endif
    }
    
    /// Send a friend request by friend code (looks up user, then sends request).
    func sendFriendRequestByCode(_ code: String) async throws {
        guard let (userId, displayName) = await lookupUserByFriendCode(code) else {
            throw NSError(domain: "FirebaseSyncService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Invalid or expired friend code"])
        }
        try await sendFriendRequest(toUserId: userId, toDisplayName: displayName)
    }
    
    /// Send a friend request to another user.
    func sendFriendRequest(toUserId: String, toDisplayName: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else {
            throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard toUserId != myId else {
            throw NSError(domain: "FirebaseSyncService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add yourself"])
        }
        
        let docId = friendDocId(myId, toUserId)
        let ref = db.collection("friends").document(docId)
        let snap = try await ref.getDocument()
        if snap.exists, let status = (snap.data()?["status"] as? String), status == "accepted" {
            throw NSError(domain: "FirebaseSyncService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Already friends"])
        }
        if snap.exists, let status = (snap.data()?["status"] as? String), status == "pending" {
            throw NSError(domain: "FirebaseSyncService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
        }
        
        let (userA, userB) = myId < toUserId ? (myId, toUserId) : (toUserId, myId)
        try await ref.setData([
            "userA": userA,
            "userB": userB,
            "status": "pending",
            "requestedBy": myId,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ])
        print("✅ [FAITH FRIENDS] Sent friend request to \(toUserId)")
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }
    
    /// Accept a friend request.
    func acceptFriendRequest(fromUserId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else {
            throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let docId = friendDocId(myId, fromUserId)
        let ref = db.collection("friends").document(docId)
        let snap = try await ref.getDocument()
        guard snap.exists, let data = snap.data() else {
            throw NSError(domain: "FirebaseSyncService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Request not found"])
        }
        guard (data["status"] as? String) == "pending", (data["requestedBy"] as? String) == fromUserId else {
            throw NSError(domain: "FirebaseSyncService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid request"])
        }
        try await ref.updateData([
            "status": "accepted",
            "updatedAt": Timestamp(date: Date())
        ])
        print("✅ [FAITH FRIENDS] Accepted friend request from \(fromUserId)")
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }
    
    /// Decline a friend request.
    func declineFriendRequest(fromUserId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else {
            throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let docId = friendDocId(myId, fromUserId)
        let ref = db.collection("friends").document(docId)
        let snap = try await ref.getDocument()
        guard snap.exists, let data = snap.data() else {
            throw NSError(domain: "FirebaseSyncService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Request not found"])
        }
        guard (data["status"] as? String) == "pending", (data["requestedBy"] as? String) == fromUserId else {
            return // Already accepted or declined elsewhere
        }
        try await ref.updateData([
            "status": "declined",
            "updatedAt": Timestamp(date: Date())
        ])
        print("✅ [FAITH FRIENDS] Declined friend request from \(fromUserId)")
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }
    
    /// Remove a friend (deletes the friendship document so both users are no longer friends).
    func removeFriend(friendUserId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else {
            throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let docId = friendDocId(myId, friendUserId)
        let ref = db.collection("friends").document(docId)
        let snap = try await ref.getDocument()
        guard snap.exists else {
            throw NSError(domain: "FirebaseSyncService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Friend not found"])
        }
        try await ref.delete()
        print("✅ [FAITH FRIENDS] Removed friend \(friendUserId)")
        #else
        throw NSError(domain: "FirebaseSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }
    
    /// Fetch friends, pending incoming, and pending outgoing (sent) requests from Firestore.
    func fetchFriendsFromFirebase() async -> (friends: [[String: Any]], pendingIncoming: [[String: Any]], pendingOutgoing: [[String: Any]]) {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return ([], [], []) }
        
        do {
            let snap = try await db.collection("friends")
                .whereField("userA", isEqualTo: myId)
                .getDocuments()
            let snap2 = try await db.collection("friends")
                .whereField("userB", isEqualTo: myId)
                .getDocuments()
            
            var friends: [[String: Any]] = []
            var pendingIncoming: [[String: Any]] = []
            var pendingOutgoing: [[String: Any]] = []
            
            for doc in snap.documents + snap2.documents {
                var data = doc.data()
                data["id"] = doc.documentID
                let userA = data["userA"] as? String ?? ""
                let userB = data["userB"] as? String ?? ""
                let status = data["status"] as? String ?? ""
                let requestedBy = data["requestedBy"] as? String ?? ""
                let otherId = userA == myId ? userB : userA
                data["friendUserId"] = otherId
                
                if status == "accepted" {
                    let (otherName, avatarURL) = await fetchUserDisplayNameAndAvatar(userId: otherId)
                    data["friendDisplayName"] = otherName ?? otherId
                    if let url = avatarURL { data["friendAvatarURL"] = url }
                    friends.append(data)
                } else if status == "pending" && requestedBy != myId {
                    let (requesterName, avatarURL) = await fetchUserDisplayNameAndAvatar(userId: requestedBy)
                    data["displayName"] = requesterName ?? requestedBy
                    if let url = avatarURL { data["avatarURL"] = url }
                    pendingIncoming.append(data)
                } else if status == "pending" && requestedBy == myId {
                    let (otherName, avatarURL) = await fetchUserDisplayNameAndAvatar(userId: otherId)
                    data["displayName"] = otherName ?? otherId
                    data["status"] = "pending"
                    if let url = avatarURL { data["avatarURL"] = url }
                    pendingOutgoing.append(data)
                }
            }
            return (friends, pendingIncoming, pendingOutgoing)
        } catch {
            print("⚠️ [FAITH FRIENDS] Failed to fetch friends: \(error.localizedDescription)")
            return ([], [], [])
        }
        #else
        return ([], [], [])
        #endif
    }

    /// Refresh pending incoming friend request count (e.g. on app become active or when More tab appears). Updates pendingFriendRequestCount.
    func refreshPendingFriendRequestCount() async {
        let (_, pending, _) = await fetchFriendsFromFirebase()
        pendingFriendRequestCount = pending.count
    }
    
    /// Fetch display name for a user ID (from userSearchProfiles or users).
    func fetchUserDisplayName(userId: String) async -> String? {
        let (name, _) = await fetchUserDisplayNameAndAvatar(userId: userId)
        return name
    }
    
    /// Fetch display name and avatar URL for a user (for Faith Friends rows).
    func fetchUserDisplayNameAndAvatar(userId: String) async -> (displayName: String?, avatarURL: String?) {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return (nil, nil) }
        do {
            let snap = try await db.collection("userSearchProfiles").document(userId).getDocument()
            let data = snap.data()
            let name = data?["displayName"] as? String
            var avatar = data?["avatarURL"] as? String
            if (name == nil || name!.isEmpty) || avatar == nil {
                let userSnap = try await db.collection("users").document(userId).getDocument()
                let userData = userSnap.data()
                let userName = name ?? userData?["name"] as? String
                if avatar == nil { avatar = userData?["profileImageURL"] as? String }
                return (userName, avatar)
            }
            return (name, avatar)
        } catch { return (nil, nil) }
        #else
        return (nil, nil)
        #endif
    }
    
    /// Notify friends when current user creates/activates a live session.
    // MARK: - Shared Prayer Wall

    /// Reading plans a friend has marked as shared (for group progress in Faith Friends).
    func fetchSharedReadingPlansForFriend(friendUserId: String) async -> [[String: Any]] {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return [] }
        do {
            let snap = try await db.collection("users").document(friendUserId)
                .collection("readingPlans")
                .whereField("sharedWithFriends", isEqualTo: true)
                .limit(to: 20)
                .getDocuments()
            return snap.documents.map { doc in
                var d = doc.data()
                d["planDocumentId"] = doc.documentID
                return d
            }
        } catch {
            print("⚠️ [FAITH FRIENDS] fetchSharedReadingPlansForFriend: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    /// Fetches shared reading plans for every friend (for the group progress list).
    func fetchFriendsSharedReadingPlans() async -> [[String: Any]] {
        #if canImport(FirebaseFirestore)
        guard let myId = getCurrentUserId(), db != nil else { return [] }
        let (friends, _, _) = await fetchFriendsFromFirebase()
        var results: [[String: Any]] = []
        await withTaskGroup(of: [[String: Any]].self) { group in
            for f in friends {
                guard let friendId = f["friendUserId"] as? String, friendId != myId else { continue }
                let friendName = f["friendDisplayName"] as? String ?? "Friend"
                group.addTask {
                    let plans = await self.fetchSharedReadingPlansForFriend(friendUserId: friendId)
                    return plans.map { var d = $0; d["ownerId"] = friendId; d["ownerName"] = friendName; return d }
                }
            }
            for await batch in group { results.append(contentsOf: batch) }
        }
        return results
        #else
        return []
        #endif
    }

    func fetchFriendsSharedPrayers() async -> [[String: Any]] {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return [] }
        let (friends, _, _) = await fetchFriendsFromFirebase()
        var results: [[String: Any]] = []
        await withTaskGroup(of: [[String: Any]].self) { group in
            for f in friends {
                guard let friendId = f["friendUserId"] as? String, friendId != myId else { continue }
                let friendName = f["friendDisplayName"] as? String ?? "Friend"
                group.addTask {
                    do {
                        let snap = try await db.collection("users").document(friendId)
                            .collection("sharedPrayers")
                            .order(by: "updatedAt", descending: true)
                            .limit(to: 10)
                            .getDocuments()
                        return snap.documents.map { doc -> [String: Any] in
                            var d = doc.data()
                            d["ownerId"] = friendId
                            d["ownerName"] = friendName
                            d["ownerAvatarURL"] = f["friendAvatarURL"] as? String ?? ""
                            return d
                        }
                    } catch { return [] }
                }
            }
            for await batch in group { results.append(contentsOf: batch) }
        }
        return results.sorted {
            let a = ($0["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let b = ($1["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return a > b
        }
        #else
        return []
        #endif
    }

    func prayForFriend(ownerId: String, prayerId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return }
        let ref = db.collection("users").document(ownerId)
            .collection("sharedPrayers").document(prayerId)
        try await ref.updateData(["intercessorIds": FieldValue.arrayUnion([myId])])
        // Notify the owner
        let alertRef = db.collection("users").document(ownerId)
            .collection("prayerIntercessorAlerts").document("\(prayerId)-\(myId)")
        let myName = await fetchUserDisplayName(userId: myId) ?? "A friend"
        try await alertRef.setData([
            "prayerId": prayerId,
            "intercessorId": myId,
            "intercessorName": myName,
            "createdAt": Timestamp(date: Date())
        ])
        #endif
    }

    // MARK: - Accountability Partner

    func setAccountabilityPartner(friendUserId: String, friendDisplayName: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return }
        do {
            try await db.collection("users").document(myId).setData([
                "accountabilityPartnerId": friendUserId,
                "accountabilityPartnerName": friendDisplayName
            ], merge: true)
        } catch {
            print("⚠️ [FAITH FRIENDS] Failed to set accountability partner: \(error.localizedDescription)")
        }
        #endif
    }

    func removeAccountabilityPartner() async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return }
        do {
            try await db.collection("users").document(myId).updateData([
                "accountabilityPartnerId": FieldValue.delete(),
                "accountabilityPartnerName": FieldValue.delete()
            ])
        } catch {
            print("⚠️ [FAITH FRIENDS] Failed to remove accountability partner: \(error.localizedDescription)")
        }
        #endif
    }

    func fetchAccountabilityPartner() async -> (userId: String, name: String)? {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return nil }
        do {
            let doc = try await db.collection("users").document(myId).getDocument()
            guard let data = doc.data(),
                  let partnerId = data["accountabilityPartnerId"] as? String,
                  let partnerName = data["accountabilityPartnerName"] as? String else { return nil }
            return (partnerId, partnerName)
        } catch { return nil }
        #else
        return nil
        #endif
    }

    func notifyFriendsOfNewSession(session: LiveSession) async {
        #if canImport(FirebaseFirestore)
        guard let db = db, let myId = getCurrentUserId() else { return }
        let (friends, _, _) = await fetchFriendsFromFirebase()
        for f in friends {
            guard let friendId = f["friendUserId"] as? String else { continue }
            do {
                let alertRef = db.collection("users").document(friendId).collection("friendSessionAlerts").document(session.id.uuidString)
                try await alertRef.setData([
                    "sessionId": session.id.uuidString,
                    "sessionTitle": session.title,
                    "hostId": myId,
                    "hostName": session.hostName,
                    "createdAt": Timestamp(date: Date())
                ])
            } catch {
                print("⚠️ [FAITH FRIENDS] Failed to notify friend \(friendId): \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    // MARK: - Prayer Wall (Feature 1)

    func submitPrayerWallRequest(sessionId: UUID, text: String, authorName: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString)
            .collection("prayerWall").document()
        try? await ref.setData([
            "id": ref.documentID,
            "text": text,
            "authorName": authorName,
            "isPinned": false,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func setPrayerWallPinned(sessionId: UUID, requestId: String, pinned: Bool) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString)
            .collection("prayerWall").document(requestId)
        try? await ref.updateData(["isPinned": pinned])
        #endif
    }

    func listenForPrayerWall(sessionId: UUID, onChange: @escaping ([[String: Any]]) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        return db.collection("sessions").document(sessionId.uuidString)
            .collection("prayerWall")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snap, _ in
                onChange(snap?.documents.map { ["id": $0.documentID] .merging($0.data()) { _, new in new } } ?? [])
            }
        #else
        return nil
        #endif
    }

    // MARK: - Scripture Overlay (Feature 2)

    func pushScriptureOverlay(sessionId: UUID, reference: String, text: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        let ref = db.collection("sessions").document(sessionId.uuidString)
            .collection("overlays").document("scripture")
        try? await ref.setData([
            "reference": reference,
            "text": text,
            "activeAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func dismissScriptureOverlay(sessionId: UUID) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return }
        try? await db.collection("sessions").document(sessionId.uuidString)
            .collection("overlays").document("scripture").delete()
        #endif
    }

    func listenForScriptureOverlay(sessionId: UUID, onChange: @escaping ([String: Any]?) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        guard let db = db else { return nil }
        return db.collection("sessions").document(sessionId.uuidString)
            .collection("overlays").document("scripture")
            .addSnapshotListener { snap, _ in
                onChange(snap?.exists == true ? snap?.data() : nil)
            }
        #else
        return nil
        #endif
    }

    func removeListener(_ listener: Any?) {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
    }

    // MARK: - Helper Methods

    private func getCurrentUserId() -> String? {
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            let userId = user.uid
            let email = user.email ?? "no email"
            print("🔑 [FIREBASE] Firebase Auth User authenticated:")
            print("   - User ID: \(userId)")
            print("   - Email: \(email)")
            print("   - Provider: \(user.providerData.first?.providerID ?? "unknown")")
            print("🔑 [FIREBASE] This user ID must match on all devices for sync to work")
            return userId
        } else {
            #if targetEnvironment(simulator) || os(macOS)
            // For simulator/macOS demo mode, use a shared test user ID so sync works without Sign in with Apple
            // IMPORTANT: Firestore rules allow this test user (isTestUser). On iOS real devices, Sign in with Apple required.
            let testUserId = "simulator-test-user-shared"
            #if targetEnvironment(simulator)
            print("⚠️ [FIREBASE] No Firebase Auth user in simulator - using test user ID for demo sync")
            #else
            print("⚠️ [FIREBASE] No Firebase Auth user on macOS - using test user ID for demo sync")
            #endif
            print("⚠️ [FIREBASE] Using shared test user ID: \(testUserId)")
            print("⚠️ [FIREBASE] On iOS real devices, users must sign in with Apple for sync to work")
            return testUserId
            #else
            print("⚠️ [FIREBASE] No Firebase Auth user - user must sign in with Apple")
            print("⚠️ [FIREBASE] Without sign-in, sync won't work on real devices")
            print("⚠️ [FIREBASE] Make sure you're signed in with the same Apple ID on both devices")
            return nil
            #endif
        }
        #else
        print("⚠️ [FIREBASE] Firebase Auth not available")
        return nil
        #endif
    }
    
    deinit {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        invitationListener?.remove()
        friendSessionAlertsListener?.remove()
        #endif
        
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        #endif
    }
    #endif
}

