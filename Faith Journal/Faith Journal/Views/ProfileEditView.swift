//
//  ProfileEditView.swift
//  Faith Journal
//
//  Edit user profile information
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileEditView: View {
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(profile: UserProfile?) {
        self.profile = profile
        if let profile = profile {
            _name = State(initialValue: profile.name)
            _email = State(initialValue: profile.email ?? "")
            // Load existing avatar if available
            if let avatarURL = profile.avatarPhotoURL,
               let imageData = try? Data(contentsOf: avatarURL),
               let image = UIImage(data: imageData) {
                _avatarImage = State(initialValue: image)
            }
        } else {
            _name = State(initialValue: UIDevice.current.name)
            _email = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Photo")) {
                    HStack {
                        Spacer()
                        
                        // Avatar Circle
                        if let avatarImage = avatarImage {
                            Image(uiImage: avatarImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(name.prefix(1).uppercased()))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Choose Photo")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await MainActor.run {
                                    avatarImage = image
                                }
                            }
                        }
                    }
                    
                    if avatarImage != nil {
                        Button(role: .destructive) {
                            avatarImage = nil
                            selectedPhoto = nil
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Photo")
                            }
                        }
                    }
                }
                
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section(footer: Text("Your name will be displayed on the home screen. Email is optional and can be used for account recovery.")) {
                    EmptyView()
                }
            }
            .navigationTitle(profile == nil ? "Set Up Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            showingError = true
            return
        }
        
        // Validate email format if provided
        if !trimmedEmail.isEmpty {
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            if !emailPredicate.evaluate(with: trimmedEmail) {
                errorMessage = "Please enter a valid email address"
                showingError = true
                return
            }
        }
        
        // Save avatar photo if selected
        var avatarURL: URL? = nil
        if let avatarImage = avatarImage {
            // Save image to documents directory
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileName = "avatar_\(UUID().uuidString).jpg"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Compress image before saving
                if let imageData = avatarImage.jpegData(compressionQuality: 0.8) {
                    do {
                        try imageData.write(to: fileURL)
                        avatarURL = fileURL
                        
                        // Delete old avatar if exists and is different
                        if let existingProfile = profile,
                           let oldAvatarURL = existingProfile.avatarPhotoURL,
                           oldAvatarURL != fileURL {
                            try? FileManager.default.removeItem(at: oldAvatarURL)
                        }
                    } catch {
                        print("Error saving avatar: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Remove avatar if image was cleared
            if let existingProfile = profile,
               let oldAvatarURL = existingProfile.avatarPhotoURL {
                try? FileManager.default.removeItem(at: oldAvatarURL)
            }
        }
        
        if let existingProfile = profile {
            // Update existing profile
            existingProfile.name = trimmedName
            existingProfile.email = trimmedEmail.isEmpty ? nil : trimmedEmail
            existingProfile.avatarPhotoURL = avatarURL
            existingProfile.updatedAt = Date()
        } else {
            // Create new profile
            let newProfile = UserProfile(name: trimmedName, email: trimmedEmail.isEmpty ? nil : trimmedEmail)
            newProfile.avatarPhotoURL = avatarURL
            modelContext.insert(newProfile)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            showingError = true
        }
    }
}

import UIKit

