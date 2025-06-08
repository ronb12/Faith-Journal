import SwiftUI

struct JournalView: View {
    @State private var showingNewEntry = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Journal entries will be listed here
                Text("Your journal entries will appear here")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Journal")
            .searchable(text: $searchText, prompt: "Search entries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
        }
    }
}

#Preview {
    JournalView()
} 