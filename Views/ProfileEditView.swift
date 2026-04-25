//
//  ProfileEditView.swift
//  Faith Journal
//
//  Edit user profile information with Firebase persistence
//

import SwiftUI
import SwiftData

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@available(iOS 17.0, macOS 14.0, *)
struct ProfileEditView: View {
    let profile: UserProfile?
    
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var userName: String = ""
    @State private var profileImage: PlatformImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    init(profile: UserProfile? = nil) {
        self.profile = profile
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $userName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Text("Profile Information")
                }
                
                Section {
                    if let image = profileImage {
                        #if os(iOS)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                            .padding()
                        #else
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                            .padding()
                        #endif
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
                        .padding()
                    }
                    
                    Button("Change Picture") {
                        showingImagePicker = true
                    }
                } header: {
                    Text("Profile Picture")
                } footer: {
                    Text("Tap to select a new profile picture. Your profile picture will be saved to Firebase and synced across all your devices.")
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
                        }
                    }
                    .disabled(isLoading || userName.isEmpty)
                }
            }
            .navigationTitle("Edit Profile")
            #if os(iOS)
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
                    .macOSSheetFrameCompact()
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                MacImagePicker(image: $profileImage)
                    .macOSSheetFrameCompact()
            }
            #endif
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
                Text("Profile saved successfully! Your profile will be available on all your devices.")
            }
            .onAppear {
                loadProfile()
            }
            .onChange(of: profileManager.userName) { oldValue, newValue in
                if !newValue.isEmpty {
                    userName = newValue
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadProfile() {
        Task {
            await profileManager.loadProfile()

            await MainActor.run {
                userName = profileManager.userName
            }

            let urlString = await MainActor.run { profileManager.profileImageURL }
            if let urlString {
                do {
                    if let image = try await profileManager.loadProfileImage(from: urlString) {
                        await MainActor.run {
                            self.profileImage = image
                        }
                    }
                } catch {
                    print("Error loading profile image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveProfile() async {
        await MainActor.run { isLoading = true; errorMessage = "" }
        let nameToSave = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await profileManager.saveProfile(
                        name: nameToSave.isEmpty ? nil : nameToSave,
                        image: profileImage
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)  // 15 second timeout
                    throw NSError(domain: "ProfileEditView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save timed out. Check your network connection and try again."])
                }
                _ = try await group.next()!
                group.cancelAll()
            }

            await MainActor.run {
                if let profile = profile {
                    if !nameToSave.isEmpty { profile.name = nameToSave }
                    profile.avatarPhotoURL = profileManager.profileImageURL
                    try? modelContext.save()
                }
                isLoading = false
                showSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Image Picker

#if os(iOS)
import UIKit
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: PlatformImage?
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
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#elseif os(macOS)
import AppKit
struct MacImagePicker: View {
    @Binding var image: PlatformImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Profile Image")
                .font(.headline)
            Button("Choose File...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.image]
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    if response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                        image = platformImageFromData(data)
                    }
                    dismiss()
                }
            }
            Button("Cancel") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 300)
    }
}
#endif