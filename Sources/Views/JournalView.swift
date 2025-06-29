import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: [SortDescriptor(\.date, order: .reverse)]) var entries: [JournalEntry]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundColor(themeManager.colors.primary)
                        Text(entry.content)
                            .font(.body)
                            .lineLimit(2)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: deleteEntry)
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

struct NewJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var isPrivate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $title)
                }
                Section(header: Text("Content")) {
                    TextEditor(text: $content)
                        .frame(height: 120)
                }
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                Section {
                    Toggle("Private", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntry() }
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            title: title,
            content: content,
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            isPrivate: isPrivate
        )
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
} 