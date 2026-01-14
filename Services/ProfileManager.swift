import Foundation
import UIKit

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
    private let db = Firestore.firestore()
    #else
    private let db: Any? = nil
    #endif
    
    #if canImport(FirebaseStorage)
    private let storage = Storage.storage()
    #else
    private let storage: Any? = nil
    #endif
    
    @Published var userName: String = ""
    @Published var profileImageURL: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        Task { @MainActor in
            await loadProfile()
        }
    }
    
    // MARK: - Save Profile
    
    /// Save profile name to Firestore
    func saveProfileName(_ name: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProfileError.notAuthenticated
        }
        
        let userRef = db.collection("users").document(userId)
        try await userRef.setData([
            "name": name,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
        
        self.userName = name
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save profile picture to local storage and update Firestore
    func saveProfilePicture(_ image: UIImage) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ [ProfileManager] User not authenticated")
            throw ProfileError.notAuthenticated
        }
        
        print("🔄 [ProfileManager] Starting profile picture save for user: \(userId)")
        print("📸 [ProfileManager] Image size: \(image.size.width)x\(image.size.height)")
        print("📸 [ProfileManager] Image scale: \(image.scale)")
        
        // Convert image to JPEG data - try multiple compression qualities if needed
        let imageData: Data
        var compressionQuality: CGFloat = 0.8
        var attempts = 0
        let maxAttempts = 3
        
        while attempts < maxAttempts {
            if let data = image.jpegData(compressionQuality: compressionQuality) {
                imageData = data
                print("✅ [ProfileManager] Image converted to JPEG data: \(data.count) bytes (quality: \(compressionQuality))")
                break
            } else {
                attempts += 1
                compressionQuality -= 0.2
                print("⚠️ [ProfileManager] JPEG conversion failed, trying lower quality: \(compressionQuality)")
            }
        }
        
        guard attempts < maxAttempts else {
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
    
    /// Save both name and picture
    func saveProfile(name: String?, image: UIImage?) async throws {
        print("🔄 [ProfileManager] saveProfile called - name: \(name ?? "nil"), image: \(image != nil ? "present" : "nil")")
        
        self.isLoading = true
        self.errorMessage = nil
        
        defer {
            self.isLoading = false
        }
        
        do {
            if let name = name, !name.isEmpty {
                print("💾 [ProfileManager] Saving profile name...")
                try await saveProfileName(name)
            }
            
            if let image = image {
                print("📸 [ProfileManager] Saving profile picture...")
                try await saveProfilePicture(image)
            } else {
                // Check if user wants to remove existing image
                // If profileImageURL exists but no new image provided, we keep the existing one
                // Only remove if explicitly requested (handled in ProfileEditView)
                print("ℹ️ [ProfileManager] No image provided, keeping existing image if any")
            }
        } catch {
            print("❌ [ProfileManager] Error in saveProfile: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
            }
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        print("✅ [ProfileManager] saveProfile completed successfully")
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
            return
        }
        
        print("🔄 [ProfileManager] Loading profile for user: \(userId)")
        
        self.isLoading = true
        
        defer {
            self.isLoading = false
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists, let data = document.data() else {
                print("ℹ️ [ProfileManager] No profile document found for user: \(userId)")
                return
            }
            
            var updated = false
            
            if let name = data["name"] as? String {
                if self.userName != name {
                    self.userName = name
                    updated = true
                    print("✅ [ProfileManager] Loaded profile name: \(name)")
                }
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
        #else
        print("⚠️ [ProfileManager] Firebase not available, cannot load profile")
        self.userName = ""
        self.profileImageURL = nil
        #endif
    }
    
    /// Load profile image from URL (supports both local file paths and remote URLs)
    nonisolated func loadProfileImage(from urlString: String) async throws -> UIImage? {
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
            return UIImage(data: data)
        } else {
            // Remote URL (for backward compatibility if needed)
            guard let url = URL(string: urlString) else {
                return nil
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
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
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidImage:
            return "Invalid image data"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
