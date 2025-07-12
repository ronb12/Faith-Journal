import SwiftUI

struct SearchView: View {
    @State private var query = ""
    var body: some View {
        VStack {
            TextField("Search...", text: $query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Text("Search results will appear here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
} 