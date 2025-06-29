import SwiftUI
import SwiftData

struct PrayerView: View {
    @Query(sort: [SortDescriptor(\.date, order: .reverse)]) var requests: [PrayerRequest]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewRequest = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(requests) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.title)
                            .font(.headline)
                            .foregroundColor(themeManager.colors.primary)
                        Text(request.description)
                            .font(.body)
                            .lineLimit(2)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text(request.date, style: .date)
                            .font(.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text("Status: \(request.status.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: deleteRequest)
            }
            .navigationTitle("Prayer Requests")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewRequest = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewRequest) {
                NewPrayerRequestView()
            }
        }
    }
    
    private func deleteRequest(at offsets: IndexSet) {
        for index in offsets {
            let request = requests[index]
            modelContext.delete(request)
        }
        try? modelContext.save()
    }
}

struct NewPrayerRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var description = ""
    @State private var tags = ""
    @State private var isPrivate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $title)
                }
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                Section {
                    Toggle("Private", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Prayer Request")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveRequest() }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveRequest() {
        let request = PrayerRequest(
            title: title,
            description: description,
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            isPrivate: isPrivate
        )
        modelContext.insert(request)
        try? modelContext.save()
        dismiss()
    }
} 