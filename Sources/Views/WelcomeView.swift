import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Faith Journal")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your journey of faith, reflection, and prayer starts here.")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
} 