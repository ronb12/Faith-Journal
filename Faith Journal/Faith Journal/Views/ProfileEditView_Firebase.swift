import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@available(iOS 17.0, *)
struct ProfileEditView: View {
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var userName: String = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
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
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                            .padding()
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
                    Text("Tap to select a new profile picture")
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
            .onChange(of: profileManager.userName) { newValue in
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
            
            // Update local state from ProfileManager
            await MainActor.run {
                userName = profileManager.userName
            }

            // Load profile image if URL exists
            if let urlString = profileManager.profileImageURL {
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
        isLoading = true
        errorMessage = ""
        
        do {
            try await profileManager.saveProfile(
                name: userName.trimmingCharacters(in: .whitespacesAndNewlines),
                image: profileImage
            )
            
            await MainActor.run {
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

