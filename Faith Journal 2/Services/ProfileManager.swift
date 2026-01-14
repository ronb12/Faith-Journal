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
        loadProfile()
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
        
        await MainActor.run {
            self.userName = name
        }
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save profile picture to Firebase Storage and update Firestore
    func saveProfilePicture(_ image: UIImage) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseStorage) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProfileError.notAuthenticated
        }
        
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ProfileError.invalidImage
        }
        
        // Create storage reference
        let imageRef = storage.reference().child("profilePictures/\(userId).jpg")
        
        // Upload image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            imageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let metadata = metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: ProfileError.unknown)
                }
            }
        }
        
        // Get download URL
        let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            imageRef.downloadURL { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ProfileError.unknown)
                }
            }
        }
        let urlString = downloadURL.absoluteString
        
        // Save URL to Firestore
        let userRef = db.collection("users").document(userId)
        try await userRef.setData([
            "profileImageURL": urlString,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
        
        await MainActor.run {
            self.profileImageURL = urlString
        }
        #else
        throw ProfileError.notAuthenticated
        #endif
    }
    
    /// Save both name and picture
    func saveProfile(name: String?, image: UIImage?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            if let name = name, !name.isEmpty {
                try await saveProfileName(name)
            }
            
            if let image = image {
                try await saveProfilePicture(image)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Load Profile
    
    /// Load profile from Firestore
    func loadProfile() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [ProfileManager] User not authenticated, cannot load profile")
            // Clear profile if user is not authenticated
            userName = ""
            profileImageURL = nil
            return
        }
        
        print("🔄 [ProfileManager] Loading profile for user: \(userId)")
        isLoading = true
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ [ProfileManager] Error loading profile: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    print("ℹ️ [ProfileManager] No profile document found for user: \(userId)")
                    // Profile doesn't exist yet - that's okay, user can create one
                    return
                }
                
                if let name = data["name"] as? String {
                    self.userName = name
                    print("✅ [ProfileManager] Loaded profile name: \(name)")
                }
                
                if let urlString = data["profileImageURL"] as? String {
                    self.profileImageURL = urlString
                    print("✅ [ProfileManager] Loaded profile image URL: \(urlString)")
                }
            }
        }
        #else
        print("⚠️ [ProfileManager] Firebase not available, cannot load profile")
        userName = ""
        profileImageURL = nil
        #endif
    }
    
    /// Load profile image from URL
    func loadProfileImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    // MARK: - Clear Profile
    
    func clearProfile() {
        userName = ""
        profileImageURL = nil
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

