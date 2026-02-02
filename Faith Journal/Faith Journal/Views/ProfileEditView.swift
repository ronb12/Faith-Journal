//
//  ProfileEditView.swift
//  Faith Journal
//
//  Edit user profile information with local storage for images
//

import SwiftUI
import SwiftData
import Photos

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@available(iOS 17.0, *)
struct ProfileEditView: View {
    // Accept optional profile parameter for compatibility, but use Firebase instead
    let profile: UserProfile? = nil
    
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var userName: String = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Compatibility initializer - profile is ignored, Firebase is used instead
    init(profile: UserProfile? = nil) {
        // Profile parameter accepted for compatibility but not used
        // All data comes from Firebase via ProfileManager
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $userName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Profile Information")
                }
                
                Section {
                    VStack(spacing: 16) {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 200)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 200)
                                
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                showingImagePicker = true
                            } label: {
                                Label(profileImage == nil ? "Add Picture" : "Change Picture", systemImage: "photo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            if profileImage != nil {
                                Button {
                                    profileImage = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile Picture")
                } footer: {
                    Text("Your profile picture is saved locally on your device. Your profile information syncs across devices when signed in with Apple.")
                }
                
                Section {
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                            }
                            Text("Save Profile")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $profileImage)
                    .onChange(of: profileImage) { oldValue, newValue in
                        if newValue != nil {
                            print("✅ [ProfileEditView] Profile image selected: \(newValue?.size.width ?? 0)x\(newValue?.size.height ?? 0)")
                        }
                    }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Profile saved successfully!")
            }
            .onAppear {
                loadProfile()
            }
            .onChange(of: profileManager.userName) { oldValue, newValue in
                if !newValue.isEmpty && userName != newValue {
                    userName = newValue
                    print("🔄 [ProfileEditView] userName updated from ProfileManager: \(newValue)")
                }
            }
            .onChange(of: profileManager.profileImageURL) { oldValue, newValue in
                // Reload image if URL changes
                if let urlString = newValue, urlString != oldValue {
                    Task {
                        await loadProfileImage(from: urlString)
                    }
                } else if newValue == nil && oldValue != nil {
                    // Image was removed
                    profileImage = nil
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadProfile() {
        Task {
            let manager = ProfileManager.shared
            await manager.loadProfile()
            
            await MainActor.run {
                // Update local state from ProfileManager
                userName = manager.userName
                
                // Load profile image if URL exists
                if let urlString = manager.profileImageURL {
                    Task {
                        await loadProfileImage(from: urlString)
                    }
                }
            }
        }
    }
    
    private func loadProfileImage(from urlString: String) async {
        do {
            let profileManager = ProfileManager.shared
            if let image = try await profileManager.loadProfileImage(from: urlString) {
                await MainActor.run {
                    self.profileImage = image
                }
            }
        } catch {
            print("❌ [ProfileEditView] Error loading profile image: \(error.localizedDescription)")
        }
    }
    
    private func saveProfile() async {
        print("🔄 [ProfileEditView] saveProfile called")
        print("   Name: \(userName)")
        print("   Has image: \(profileImage != nil)")
        print("   Current profileImageURL: \(profileManager.profileImageURL ?? "nil")")
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If user removed image (was nil but had URL before), remove it
            let currentImageURL = await MainActor.run {
                ProfileManager.shared.profileImageURL
            }
            
            if profileImage == nil && currentImageURL != nil {
                print("🗑️ [ProfileEditView] User removed profile picture, deleting...")
                // Remove profile picture using the shared instance
                let manager = ProfileManager.shared
                try await manager.removeProfilePicture()
            }
            
            // Save profile - image is optional, user can save just the name
            try await ProfileManager.shared.saveProfile(
                name: trimmedName.isEmpty ? nil : trimmedName,
                image: profileImage
            )
            
            print("✅ [ProfileEditView] Profile saved successfully")
            
            // Update local state from ProfileManager
            await MainActor.run {
                userName = profileManager.userName
                isLoading = false
                showSuccessAlert = true
                print("✅ [ProfileEditView] Profile saved - userName: \(userName)")
            }
        } catch {
            print("❌ [ProfileEditView] Error saving profile: \(error.localizedDescription)")
            
            // Provide user-friendly error message
            var detailedError = error.localizedDescription
            if let nsError = error as NSError? {
                if nsError.domain == NSURLErrorDomain {
                    detailedError = "Network error. Please check your internet connection and try again."
                } else if nsError.domain.contains("Firebase") {
                    detailedError = "Unable to save profile. Please check your internet connection and try again."
                } else if error is ProfileError {
                    switch error as! ProfileError {
                    case .invalidImage:
                        detailedError = "Invalid image. Please select a different image."
                    case .notAuthenticated:
                        detailedError = "Please sign in to save your profile."
                    default:
                        detailedError = "Unable to save profile. Please try again."
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
                errorMessage = detailedError
                showingError = true
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("📸 [ImagePicker] Image selected")
            
            var selectedImage: UIImage?
            
            // Try to get edited image first (if user cropped it)
            if let editedImage = info[.editedImage] as? UIImage {
                print("✅ [ImagePicker] Using edited image: \(editedImage.size.width)x\(editedImage.size.height)")
                selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                print("✅ [ImagePicker] Using original image: \(originalImage.size.width)x\(originalImage.size.height)")
                selectedImage = originalImage
            }
            
            if selectedImage == nil {
                print("❌ [ImagePicker] Failed to extract image from picker")
            }
            
            parent.image = selectedImage
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("ℹ️ [ImagePicker] User cancelled image selection")
            parent.dismiss()
        }
    }
}

// Helper to check and request photo library permission
extension ImagePicker {
    static func checkPhotoLibraryPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("📸 [ImagePicker] Photo library authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            print("✅ [ImagePicker] Photo library access granted")
            return true
        case .notDetermined:
            print("⚠️ [ImagePicker] Photo library permission not determined - will request")
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                print("📸 [ImagePicker] Permission request result: \(newStatus.rawValue)")
            }
            return false
        case .denied, .restricted:
            print("❌ [ImagePicker] Photo library access denied or restricted")
            return false
        @unknown default:
            return false
        }
    }
}
