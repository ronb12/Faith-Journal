import SwiftUI
import SwiftData
import LocalAuthentication

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("useBiometrics") private var useBiometrics = false
    @State private var isUnlocked = false
    
    var body: some View {
        Group {
            if useBiometrics {
                if isUnlocked {
                    MainTabView()
                } else {
                    BiometricUnlockView(isUnlocked: $isUnlocked)
                }
            } else {
                MainTabView()
            }
        }
    }
}

struct BiometricUnlockView: View {
    @Binding var isUnlocked: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Faith Journal is Locked")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Use Face ID or Touch ID to unlock")
                .foregroundStyle(.secondary)
            
            Button {
                authenticate()
            } label: {
                Text("Unlock")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
            Button("Skip Authentication") {
                isUnlocked = true
            }
        } message: {
            Text(errorMessage ?? "Failed to authenticate. Please try again.")
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Biometric authentication is not available."
            showingError = true
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Faith Journal") { success, authError in
            Task { @MainActor in
                if success {
                    isUnlocked = true
                } else if let error = authError {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 