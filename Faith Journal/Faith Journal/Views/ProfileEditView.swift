//
//  ProfileEditView.swift
//  Faith Journal
//
//  Edit user profile information
//

import SwiftUI
import SwiftData

struct ProfileEditView: View {
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(profile: UserProfile?) {
        self.profile = profile
        if let profile = profile {
            _name = State(initialValue: profile.name)
            _email = State(initialValue: profile.email ?? "")
        } else {
            _name = State(initialValue: UIDevice.current.name)
            _email = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
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
        
        if let existingProfile = profile {
            // Update existing profile
            existingProfile.name = trimmedName
            existingProfile.email = trimmedEmail.isEmpty ? nil : trimmedEmail
            existingProfile.updatedAt = Date()
        } else {
            // Create new profile
            let newProfile = UserProfile(name: trimmedName, email: trimmedEmail.isEmpty ? nil : trimmedEmail)
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

