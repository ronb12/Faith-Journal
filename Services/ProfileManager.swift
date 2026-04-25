import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private func _resizeImage(_ image: PlatformImage, maxDimension: CGFloat) -> PlatformImage {
    #if os(iOS)
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else { return image }
    let ratio = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    #elseif os(macOS)
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else { return image }
    let ratio = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: newSize))
    newImage.unlockFocus()
    return newImage
    #else
    return image
    #endif
}

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@available(iOS 17.0, *)
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore? {
        guard FirebaseInitializer.shared.isConfigured else {
            print("⚠️ [PROFILE] Firebase not configured yet - cannot use Firestore")
            return nil
        }
        return Firestore.firestore()
    }
    #else
    private let db: Any? = nil
    #endif
    
    #if canImport(FirebaseStorage)
    private var storage: Storage? {
        guard FirebaseInitializer.shared.isConfigured else {
            print("⚠️ [PROFILE] Firebase not configured yet - cannot access Storage")
            return nil
        }
        return Storage.storage()
    }
    #else
    private let storage: Any? = nil
    #endif
    
    @Published var userName: String = ""
    @Published var profileImageURL: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Bulk live-session tools in Settings require `admin: true` and/or `role` `admin` on the Firebase ID token (set via Admin SDK).
    @Published private(set) var isFirebaseAppAdmin: Bool = false
    
    private init() {
        Task { @MainActor in
            await loadProfile()
        }
    }
    
    // MARK: - Save Profile
    
    /// Effective user ID: Auth if signed in, or test user on simulator/macOS
    private var effectiveUserId: String? {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid { return uid }
        #if targetEnvironment(simulator) || os(macOS)
        return "simulator-test-user-shared"
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }
    
    /// Save profile name to Firestore
    func saveProfileName(_ name: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = effectiveUserId else {
            throw ProfileError.notAuthenticated
        }
        guard let db else {
            throw ProfileError.firebaseNotConfigured
        }
        
        let userRef = db.collection("users").document(userId)
        let email = Auth.auth().currentUser?.email
        let nameLower = name.lowercased()
        var userData: [String: Any] = [
            "name": name,
            "nameLower": nameLower,
            "updatedAt": Timestamp(date: Date())
        ]
        if let email, !email.isEmpty {
            userData["email"] = email
            userData["emailLower"] = email.lowercased()
        }
        try await userRef.setData(userData, merge: true)
        
        self.userName = name
        FirebaseSyncService.shared.upsertUserSearchProfile(userId: userId, displayName: name, email: email, avatarURL: profileImageURL)
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save image to local storage only; returns relative path. Used by saveProfile for combined write.
    private func saveProfileImageToLocal(_ image: PlatformImage, userId: String) async throws -> String {
        let resized = _resizeImage(image, maxDimension: 400)
        var imageData: Data?
        var compressionQuality: CGFloat = 0.7
        for _ in 0..<3 {
            if let data = platformImageToJPEGData(resized, quality: compressionQuality) {
                imageData = data
                break
            }
            compressionQuality -= 0.2
        }
        guard let imageData else { throw ProfileError.invalidImage }
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProfileError.unknown
        }
        let profilePicturesDir = documentsDirectory.appendingPathComponent("profilePictures")
        try? FileManager.default.createDirectory(at: profilePicturesDir, withIntermediateDirectories: true, attributes: nil)
        
        let imageFileName = "\(userId).jpg"
        let imageFileURL = profilePicturesDir.appendingPathComponent(imageFileName)
        if FileManager.default.fileExists(atPath: imageFileURL.path) {
            try? FileManager.default.removeItem(at: imageFileURL)
        }
        try imageData.write(to: imageFileURL, options: [.atomic])
        return "profilePictures/\(imageFileName)"
    }
    
    /// Save profile picture to local storage and update Firestore
    func saveProfilePicture(_ image: PlatformImage) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = effectiveUserId else {
            print("❌ [ProfileManager] User not authenticated")
            throw ProfileError.notAuthenticated
        }
        guard let db else {
            throw ProfileError.firebaseNotConfigured
        }
        
        // Resize large images for faster save (profile pics don't need full resolution)
        let resized = _resizeImage(image, maxDimension: 400)
        
        // Convert to JPEG - use 0.7 for smaller file, faster write
        var imageData: Data?
        var compressionQuality: CGFloat = 0.7
        var attempts = 0
        let maxAttempts = 3
        while attempts < maxAttempts {
            if let data = platformImageToJPEGData(resized, quality: compressionQuality) {
                imageData = data
                print("✅ [ProfileManager] Image converted to JPEG data: \(data.count) bytes (quality: \(compressionQuality))")
                break
            } else {
                attempts += 1
                compressionQuality -= 0.2
                print("⚠️ [ProfileManager] JPEG conversion failed, trying lower quality: \(compressionQuality)")
            }
        }
        
        guard attempts < maxAttempts, let imageData else {
            print("❌ [ProfileManager] Failed to convert image to JPEG after \(maxAttempts) attempts")
            throw ProfileError.invalidImage
        }
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [ProfileManager] Could not access documents directory")
            throw ProfileError.unknown
        }
        
        // Create profilePictures directory if it doesn't exist
        let profilePicturesDir = documentsDirectory.appendingPathComponent("profilePictures")
        do {
            try FileManager.default.createDirectory(at: profilePicturesDir, withIntermediateDirectories: true, attributes: nil)
            print("✅ [ProfileManager] Profile pictures directory ready: \(profilePicturesDir.path)")
        } catch {
            // Directory might already exist, that's okay
            if (error as NSError).code != 516 { // 516 = file exists
                print("⚠️ [ProfileManager] Could not create directory (may already exist): \(error.localizedDescription)")
            }
        }
        
        // Save image to local file
        let imageFileName = "\(userId).jpg"
        let imageFileURL = profilePicturesDir.appendingPathComponent(imageFileName)
        
        print("💾 [ProfileManager] Saving image to local storage: \(imageFileURL.path)")
        print("💾 [ProfileManager] File URL: \(imageFileURL.absoluteString)")
        
        // Remove old file if it exists
        if FileManager.default.fileExists(atPath: imageFileURL.path) {
            try? FileManager.default.removeItem(at: imageFileURL)
            print("🗑️ [ProfileManager] Removed old profile picture")
        }
        
        // Write image data to file
        do {
            try imageData.write(to: imageFileURL, options: [.atomic])
            
            // Verify file was written
            if FileManager.default.fileExists(atPath: imageFileURL.path) {
                let attributes = try? FileManager.default.attributesOfItem(atPath: imageFileURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                print("✅ [ProfileManager] Image saved to local storage successfully")
                print("   File size: \(fileSize) bytes")
                print("   File path: \(imageFileURL.path)")
            } else {
                print("❌ [ProfileManager] File was not created after write")
                throw ProfileError.unknown
            }
        } catch {
            print("❌ [ProfileManager] Error saving image to local storage: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error userInfo: \(nsError.userInfo)")
            }
            throw error
        }
        
        // Store local file path (relative to documents directory for portability)
        let relativePath = "profilePictures/\(imageFileName)"
        
        // Save path to Firestore
        print("💾 [ProfileManager] Saving profile image path to Firestore...")
        let userRef = db.collection("users").document(userId)
        let timestamp = Timestamp(date: Date())
        
        // Create dictionary on main actor to avoid warnings
        let relativePathValue = relativePath
        let timestampValue = timestamp
        let firestoreData: [String: Any] = await MainActor.run {
            [
                "profileImageURL": relativePathValue,
                "profileImageStorageType": "local",
                "updatedAt": timestampValue
            ]
        }
        
        do {
            try await userRef.setData(firestoreData, merge: true)
            print("✅ [ProfileManager] Profile image path saved to Firestore: \(relativePath)")
        } catch {
            print("❌ [ProfileManager] Error saving to Firestore: \(error.localizedDescription)")
            throw error
        }
        
        // Update published property with full file URL for display (on main actor)
        let urlString = imageFileURL.absoluteString
        await MainActor.run {
            self.profileImageURL = urlString
        }
        print("✅ [ProfileManager] Profile picture saved successfully!")
        print("✅ [ProfileManager] Profile image URL set to: \(imageFileURL.absoluteString)")
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save live session thumbnail to local storage the same way profile pictures are saved: resize, JPEG with quality fallback, atomic write, verify.
    /// Returns full file URL string or nil. Use before dismiss so thumbnail survives app restart; then upload to Firebase in background.
    func saveLiveSessionThumbnailToLocalSync(sessionId: UUID, image: PlatformImage) -> String? {
        // Same as profile picture: resize for thumbnails (max 400)
        let resized = _resizeImage(image, maxDimension: 400)
        // Same JPEG conversion as saveProfilePicture: start 0.7, retry with lower quality
        var imageData: Data?
        var compressionQuality: CGFloat = 0.7
        for _ in 0..<3 {
            if let data = platformImageToJPEGData(resized, quality: compressionQuality) {
                imageData = data
                break
            }
            compressionQuality -= 0.2
        }
        guard let imageData else {
            print("⚠️ [ProfileManager] Live session thumbnail JPEG conversion failed")
            return nil
        }
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ [ProfileManager] No documents directory for live session thumbnail")
            return nil
        }
        let dirName = "liveSessionThumbnails"
        let dir = documentsDirectory.appendingPathComponent(dirName)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            let fileName = "\(sessionId.uuidString).jpg"
            let fileURL = dir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            try imageData.write(to: fileURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("✅ [ProfileManager] Live session thumbnail saved (same as profile picture flow): \(fileURL.path)")
                return fileURL.absoluteString
            }
            print("⚠️ [ProfileManager] Live session thumbnail file not found after write")
            return nil
        } catch {
            print("⚠️ [ProfileManager] Live session thumbnail sync save failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save live session thumbnail to local storage (same flow as profile picture: resize, JPEG, write to Documents).
    /// Returns full file URL string for display. Does not touch Firestore.
    func saveLiveSessionThumbnailToLocal(sessionId: UUID, image: PlatformImage) async throws -> String {
        // Resize for thumbnails (same as profile: max 400)
        let resized = _resizeImage(image, maxDimension: 400)
        
        var imageData: Data?
        var compressionQuality: CGFloat = 0.7
        var attempts = 0
        let maxAttempts = 3
        while attempts < maxAttempts {
            if let data = platformImageToJPEGData(resized, quality: compressionQuality) {
                imageData = data
                print("✅ [ProfileManager] Live session thumbnail JPEG: \(data.count) bytes (quality: \(compressionQuality))")
                break
            }
            attempts += 1
            compressionQuality -= 0.2
        }
        guard attempts < maxAttempts, let imageData else {
            print("❌ [ProfileManager] Failed to convert thumbnail to JPEG")
            throw ProfileError.invalidImage
        }
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProfileError.unknown
        }
        
        let dirName = "liveSessionThumbnails"
        let dir = documentsDirectory.appendingPathComponent(dirName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        
        let fileName = "\(sessionId.uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        try imageData.write(to: fileURL, options: [.atomic])
        
        print("✅ [ProfileManager] Live session thumbnail saved: \(fileURL.path)")
        return fileURL.absoluteString
    }
    
    /// Remove profile picture
    @MainActor
    func removeProfilePicture() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProfileError.notAuthenticated
        }
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProfileError.unknown
        }
        
        // Remove local file
        let imageFileName = "\(userId).jpg"
        let profilePicturesDir = documentsDirectory.appendingPathComponent("profilePictures")
        let imageFileURL = profilePicturesDir.appendingPathComponent(imageFileName)
        
        if FileManager.default.fileExists(atPath: imageFileURL.path) {
            try? FileManager.default.removeItem(at: imageFileURL)
            print("🗑️ [ProfileManager] Removed profile picture from local storage")
        }
        
        guard let db else {
            throw ProfileError.firebaseNotConfigured
        }

        // Clear path in Firestore
        let userRef = db.collection("users").document(userId)
        let timestamp = Timestamp(date: Date())
        
        // Create dictionary on main actor to avoid warnings
        let timestampValue = timestamp
        let firestoreData: [String: Any] = await MainActor.run {
            [
                "profileImageURL": NSNull(),
                "profileImageStorageType": NSNull(),
                "updatedAt": timestampValue
            ]
        }
        
        try await userRef.setData(firestoreData, merge: true)
        
        // Clear published property (on main actor)
        await MainActor.run {
            self.profileImageURL = nil
        }
        print("✅ [ProfileManager] Profile picture removed successfully")
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save both name and picture. Optimized: single Firestore write when both change.
    func saveProfile(name: String?, image: PlatformImage?) async throws {
        print("🔄 [ProfileManager] saveProfile START")
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        do {
            let nameToSave = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasName = (nameToSave?.isEmpty == false)
            let hasImage = image != nil
            print("🔄 [ProfileManager] hasName=\(hasName) hasImage=\(hasImage)")

            #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
            guard let userId = effectiveUserId, let db else {
                print("❌ [ProfileManager] Abort: no userId or db (effectiveUserId=\(String(describing: effectiveUserId)) db=\(db != nil))")
                throw ProfileError.notAuthenticated
            }
            print("🔄 [ProfileManager] userId=\(userId), writing to Firestore...")
            let userRef = db.collection("users").document(userId)
            let email = Auth.auth().currentUser?.email
            
            // Build combined Firestore data - single write is faster than two
            var userData: [String: Any] = ["updatedAt": Timestamp(date: Date())]
            if hasName, let n = nameToSave {
                userData["name"] = n
                userData["nameLower"] = n.lowercased()
                self.userName = n
                if let e = email, !e.isEmpty {
                    userData["email"] = e
                    userData["emailLower"] = e.lowercased()
                }
            }
            
            if hasImage, let img = image {
                print("🔄 [ProfileManager] Saving image to local...")
                let relativePath = try await saveProfileImageToLocal(img, userId: userId)
                print("🔄 [ProfileManager] Image saved locally: \(relativePath)")
                userData["profileImageURL"] = relativePath
                userData["profileImageStorageType"] = "local"
                if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fullURL = docs.appendingPathComponent(relativePath).absoluteString
                    await MainActor.run { self.profileImageURL = fullURL }
                }
            }
            
            print("🔄 [ProfileManager] Firestore setData START...")
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await userRef.setData(userData, merge: true)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 10_000_000_000)  // 10s timeout
                        throw NSError(domain: "ProfileManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])
                    }
                    _ = try await group.next()!
                    group.cancelAll()
                }
                print("🔄 [ProfileManager] Firestore setData DONE")
            } catch let err as NSError where err.domain == "ProfileManager" && err.code == -2 {
                // Firestore timed out - profile is saved locally, sync will retry when online
                print("⚠️ [ProfileManager] Firestore timeout - profile saved locally, will sync when online")
            }
            if hasName, let n = nameToSave {
                FirebaseSyncService.shared.upsertUserSearchProfile(userId: userId, displayName: n, email: email, avatarURL: profileImageURL)
            }
            #else
            if hasName, let n = nameToSave {
                try await saveProfileName(n)
            }
            if hasImage, let img = image {
                try await saveProfilePicture(img)
            }
            #endif
        } catch {
            print("❌ [ProfileManager] Error in saveProfile: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
            }
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
        
        print("✅ [ProfileManager] saveProfile completed successfully")
    }
    
    // MARK: - Firebase admin (custom claims on ID token)
    
    @MainActor
    func refreshFirebaseAppAdminClaim() async {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            isFirebaseAppAdmin = false
            return
        }
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            let claims = result.claims
            let fromFlag = (claims["admin"] as? Bool) == true
            let role = (claims["role"] as? String)?.lowercased()
            let fromRole = role == "admin" || role == "superadmin"
            isFirebaseAppAdmin = fromFlag || fromRole
        } catch {
            print("⚠️ [ProfileManager] refreshFirebaseAppAdminClaim failed: \(error.localizedDescription)")
            isFirebaseAppAdmin = false
        }
        #else
        isFirebaseAppAdmin = false
        #endif
    }
    
    // MARK: - Load Profile
    
    /// Load profile from Firestore
    @MainActor
    func loadProfile() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [ProfileManager] User not authenticated, cannot load profile")
            self.userName = ""
            self.profileImageURL = nil
            await refreshFirebaseAppAdminClaim()
            return
        }
        
        print("🔄 [ProfileManager] Loading profile for user: \(userId)")
        
        self.isLoading = true
        
        defer {
            self.isLoading = false
        }
        
        guard let db else {
            print("⚠️ [ProfileManager] Firebase not configured yet - skipping profile load")
            await refreshFirebaseAppAdminClaim()
            return
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists, let data = document.data() else {
                print("ℹ️ [ProfileManager] No profile document found for user: \(userId)")
                await refreshFirebaseAppAdminClaim()
                return
            }
            
            var updated = false
            
            if let name = data["name"] as? String {
                if self.userName != name {
                    self.userName = name
                    updated = true
                    print("✅ [ProfileManager] Loaded profile name: \(name)")
                }
                var email = data["email"] as? String
                if (email == nil || email!.isEmpty), let authEmail = Auth.auth().currentUser?.email {
                    email = authEmail
                    // Persist email to users/ for Faith Friends search
                    try? await db.collection("users").document(userId).setData(["email": authEmail], merge: true)
                }
                let avatarURL = (data["profileImageURL"] as? String) ?? self.profileImageURL
                FirebaseSyncService.shared.upsertUserSearchProfile(userId: userId, displayName: name, email: email, avatarURL: avatarURL)
            } else {
                print("ℹ️ [ProfileManager] No name field in profile document")
            }
            
            if let urlString = data["profileImageURL"] as? String {
                // Convert relative path to full file URL if it's a local path
                let fullURLString: String
                if urlString.hasPrefix("/") || urlString.hasPrefix("file://") {
                    // Already a full path
                    fullURLString = urlString
                } else {
                    // Relative path - convert to full file URL
                    if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let fileURL = documentsDirectory.appendingPathComponent(urlString)
                        fullURLString = fileURL.absoluteString
                    } else {
                        fullURLString = urlString
                    }
                }
                
                if self.profileImageURL != fullURLString {
                    self.profileImageURL = fullURLString
                    updated = true
                    print("✅ [ProfileManager] Loaded profile image path: \(urlString)")
                }
            } else {
                print("ℹ️ [ProfileManager] No profileImageURL field in profile document")
            }
            
            if !updated {
                print("ℹ️ [ProfileManager] Profile data unchanged")
            }
        } catch {
            print("❌ [ProfileManager] Error loading profile: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
        await refreshFirebaseAppAdminClaim()
        #else
        print("⚠️ [ProfileManager] Firebase not available, cannot load profile")
        self.userName = ""
        self.profileImageURL = nil
        isFirebaseAppAdmin = false
        #endif
    }
    
    /// Load profile image from URL (supports both local file paths and remote URLs)
    nonisolated func loadProfileImage(from urlString: String) async throws -> PlatformImage? {
        // Check if it's a local file path
        if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
            // Local file path
            let fileURL: URL
            if urlString.hasPrefix("file://") {
                fileURL = URL(fileURLWithPath: urlString.replacingOccurrences(of: "file://", with: ""))
            } else if urlString.hasPrefix("/") {
                // Absolute path
                fileURL = URL(fileURLWithPath: urlString)
            } else {
                // Relative path - assume it's in documents directory
                guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return nil
                }
                fileURL = documentsDirectory.appendingPathComponent(urlString)
            }
            
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return platformImageFromData(data)
        } else {
            // Remote URL (for backward compatibility if needed)
            guard let url = URL(string: urlString) else {
                return nil
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            return platformImageFromData(data)
        }
    }
    
    // MARK: - Clear Profile
    
    func clearProfile() {
        self.userName = ""
        self.profileImageURL = nil
    }
}

enum ProfileError: LocalizedError {
    case notAuthenticated
    case invalidImage
    case networkError
    case unknown
    case firebaseNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidImage:
            return "Invalid image data"
        case .networkError:
            return "Network error occurred"
        case .firebaseNotConfigured:
            return "Firebase is not configured yet"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
