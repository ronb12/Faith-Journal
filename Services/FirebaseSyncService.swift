//
//  FirebaseSyncService.swift
//  Faith Journal
//
//  Firebase sync service for cross-device synchronization
//

import Foundation
import SwiftData
import Combine
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

@MainActor
@available(iOS 17.0, *)
class FirebaseSyncService: ObservableObject {
    static let shared = FirebaseSyncService()
    
    #if canImport(FirebaseFirestore)
    private var _db: Firestore?
    private var listener: ListenerRegistration?
    private var prayerRequestListener: ListenerRegistration?
    private var invitationListener: ListenerRegistration?

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
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
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
            return
        }
        #endif
        
        // Check if user is authenticated before starting listener
        if let userId = getCurrentUserId() {
            print("✅ [FIREBASE] User authenticated: \(userId), starting listener")
            // Test Firebase connectivity first
            Task {
                await testFirebaseConnection()
            }
            startListening()
        } else {
            print("⚠️ [FIREBASE] User not authenticated yet, listener will start after sign-in")
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
                    
                    guard self.modelContext != nil else {
                        print("⚠️ [FIREBASE] ModelContext not set yet; will start listening after configure(modelContext:)")
                        return
                    }
                    
                    // Start listeners + run an initial sync right away.
                    self.restartListening()
                    await self.syncAllData()
                    
                    // Refresh profile after sign-in.
                    await ProfileManager.shared.loadProfile()
                } else {
                    print("⚠️ [FIREBASE] Auth state changed: signed out")
                    self.stopListeningInternal()
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
        print("🧪 [FIREBASE TEST] Device: \(UIDevice.current.name)")
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
            
            let testData: [String: Any] = [
                "timestamp": Timestamp(date: Date()),
                "device": UIDevice.current.name,
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
                "device": UIDevice.current.name,
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
    
    /// Sync a journal entry to Firebase
    func syncJournalEntry(_ entry: JournalEntry) async {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ [FIREBASE] Cannot sync - Firebase Firestore not available")
            syncError = "Firebase not configured"
            return
        }
        
        guard let userId = getCurrentUserId() else {
            print("❌ [FIREBASE] Cannot sync - user not authenticated")
            print("❌ [FIREBASE] User must sign in with Apple for sync to work")
            syncError = "User not authenticated. Please sign in with Apple."
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            let entryRef = db.collection("users").document(userId)
                .collection("journalEntries").document(entry.id.uuidString)
            
            let data: [String: Any] = [
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
        
        isSyncing = false
        #else
        print("⚠️ [FIREBASE] Firebase not available - cannot sync")
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
                    for documentChange in snapshot.documentChanges {
                        self.handleInvitationChange(documentChange)
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

        // A public-ish index for join-by-code. The Firestore rules should restrict what fields are readable.
        // Document id is the invite code for quick lookup.
        let ref = db.collection("sessionInviteCodes").document(code)
        let data: [String: Any] = [
            "inviteCode": code,
            "invitationId": invitation.id.uuidString,
            "sessionId": invitation.sessionId.uuidString,
            "sessionTitle": invitation.sessionTitle,
            "hostId": invitation.hostId,
            "hostName": invitation.hostName,
            "createdAt": Timestamp(date: invitation.createdAt),
            "expiresAt": invitation.expiresAt.map { Timestamp(date: $0) } ?? NSNull(),
            "lastSyncedAt": Timestamp(date: Date())
        ]

        do {
            try await ref.setData(data, merge: true)
            print("✅ [INVITE CODE] Published invite code index: \(code)")
        } catch {
            print("⚠️ [INVITE CODE] Failed to publish invite code index: \(error.localizedDescription)")
        }
    }

    /// Resolve an invite code via Firestore (cross-device join by code).
    func fetchInviteCodeRecord(code: String) async -> [String: Any]? {
        guard let db = db else { return nil }
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        do {
            let snap = try await db.collection("sessionInviteCodes").document(normalized).getDocument()
            guard snap.exists else { return nil }
            return snap.data()
        } catch {
            print("⚠️ [INVITE CODE] Failed to fetch invite code record: \(error.localizedDescription)")
            return nil
        }
    }

    /// Publish a live session for discovery/join-by-code.
    func syncLiveSessionPublic(_ session: LiveSession) async {
        guard let db = db else { return }

        let ref = db.collection("liveSessions").document(session.id.uuidString)
        let data: [String: Any] = [
            "id": session.id.uuidString,
            "title": session.title,
            "details": session.details,
            "hostId": session.hostId,
            "hostName": session.hostName,
            "hostBio": session.hostBio,
            "category": session.category,
            "tags": session.tags,
            "isPrivate": session.isPrivate,
            "isActive": session.isActive,
            "maxParticipants": session.maxParticipants,
            "currentParticipants": session.currentParticipants,
            "streamMode": session.streamMode,
            "durationLimitMinutes": session.durationLimitMinutes,
            "startTime": Timestamp(date: session.startTime),
            "scheduledStartTime": session.scheduledStartTime.map { Timestamp(date: $0) } ?? NSNull(),
            "endTime": session.endTime.map { Timestamp(date: $0) } ?? NSNull(),
            "createdAt": Timestamp(date: session.createdAt),
            "lastSyncedAt": Timestamp(date: Date())
        ]

        do {
            try await ref.setData(data, merge: true)
            print("✅ [LIVE SESSION] Synced public live session: \(session.id.uuidString)")
        } catch {
            print("⚠️ [LIVE SESSION] Failed to sync public live session: \(error.localizedDescription)")
        }
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
            session.isPrivate = data["isPrivate"] as? Bool ?? session.isPrivate
            session.isActive = data["isActive"] as? Bool ?? session.isActive
            session.currentParticipants = data["currentParticipants"] as? Int ?? session.currentParticipants
            session.streamMode = data["streamMode"] as? String ?? session.streamMode
            session.durationLimitMinutes = data["durationLimitMinutes"] as? Int ?? session.durationLimitMinutes

            if let ts = data["startTime"] as? Timestamp { session.startTime = ts.dateValue() }
            if let ts = data["scheduledStartTime"] as? Timestamp { session.scheduledStartTime = ts.dateValue() }
            if let ts = data["endTime"] as? Timestamp { session.endTime = ts.dateValue() }
            if let ts = data["createdAt"] as? Timestamp { session.createdAt = ts.dateValue() }

            return session
        } catch {
            print("⚠️ [LIVE SESSION] Failed to fetch public live session: \(error.localizedDescription)")
            return nil
        }
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
    private func handleInvitationChange(_ change: DocumentChange) {
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
                "createdAt": Timestamp(date: request.createdAt),
                "updatedAt": Timestamp(date: request.updatedAt)
            ]
            
            try await requestRef.setData(data, merge: true)
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
    
    /// Sync all local data to Firebase
    func syncAllData() async {
        #if canImport(FirebaseFirestore)
        guard let modelContext = modelContext else {
            print("⚠️ [FIREBASE] Cannot sync - modelContext not set")
            return
        }
        
        guard let userId = getCurrentUserId() else {
            print("❌ [FIREBASE] Cannot sync - user not authenticated")
            print("❌ [FIREBASE] User must sign in with Apple for sync to work")
            syncError = "User not authenticated. Please sign in with Apple."
            return
        }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 [FIREBASE] Starting full sync for user: \(userId)")
        
        var syncedCount = 0
        var errorCount = 0
        
        // Sync journal entries
        let journalDescriptor = FetchDescriptor<JournalEntry>()
        if let entries = try? modelContext.fetch(journalDescriptor) {
            print("📝 [FIREBASE] Syncing \(entries.count) journal entries...")
            for entry in entries {
                await syncJournalEntry(entry)
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
        isSyncing = false
        
        if errorCount > 0 {
            print("⚠️ [FIREBASE] Full sync completed with \(errorCount) errors")
        } else {
            print("✅ [FIREBASE] Full sync completed successfully")
        }
        #else
        print("⚠️ [FIREBASE] Firebase not available - cannot sync")
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
            #if targetEnvironment(simulator)
            // For simulator testing, use a shared test user ID so both simulators can sync
            // IMPORTANT: This requires Firestore security rules to allow this test user
            // For production, users must sign in with Apple to get a real Firebase Auth user
            let testUserId = "simulator-test-user-shared"
            print("⚠️ [FIREBASE] No Firebase Auth user in simulator")
            print("⚠️ [FIREBASE] Using shared test user ID for cross-device sync testing: \(testUserId)")
            print("⚠️ [FIREBASE] Both simulators will use this same ID to test sync")
            print("⚠️ [FIREBASE] On real devices, users must sign in with Apple for sync to work")
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
        #endif
        
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        #endif
    }
}

