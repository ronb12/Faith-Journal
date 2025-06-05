import SwiftUI
import SwiftData

struct NewPrayerRequestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var details = ""
    @State private var category: String?
    @State private var reminderDate: Date?
    @State private var showingReminderPicker = false
    @State private var tags: [String] = []
    @State private var isPrivate = false
    
    @State private var showingTagSheet = false
    @State private var newTag = ""
    
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextEditor(text: $details)
                    .frame(height: 150)
            }
            
            Section("Category") {
                TextField("Optional category", text: .init(
                    get: { category ?? "" },
                    set: { category = $0.isEmpty ? nil : $0 }
                ))
            }
            
            Section("Reminder") {
                Toggle("Set Reminder", isOn: .init(
                    get: { reminderDate != nil },
                    set: { if $0 { showingReminderPicker = true } else { reminderDate = nil } }
                ))
                
                if let date = reminderDate {
                    DatePicker("Reminder Date", selection: .init(
                        get: { date },
                        set: { reminderDate = $0 }
                    ))
                }
            }
            
            Section("Tags") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Button("Manage Tags") {
                    showingTagSheet = true
                }
            }
            
            Section {
                Toggle("Private Prayer", isOn: $isPrivate)
            }
        }
        .navigationTitle("New Prayer Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    savePrayer()
                }
                .disabled(title.isEmpty || details.isEmpty)
            }
        }
        .sheet(isPresented: $showingReminderPicker) {
            NavigationStack {
                Form {
                    DatePicker("Reminder Date", selection: .init(
                        get: { reminderDate ?? Date() },
                        set: { reminderDate = $0 }
                    ))
                }
                .navigationTitle("Set Reminder")
                .toolbar {
                    Button("Done") {
                        showingReminderPicker = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagSheet) {
            NavigationStack {
                List {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    tags.removeAll { $0 == tag }
                                }
                            }
                    }
                    
                    HStack {
                        TextField("New tag", text: $newTag)
                        
                        Button("Add") {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                    }
                }
                .navigationTitle("Manage Tags")
                .toolbar {
                    Button("Done") {
                        showingTagSheet = false
                    }
                }
            }
        }
    }
    
    private func savePrayer() {
        let prayer = PrayerRequest(
            title: title,
            details: details,
            category: category,
            reminderDate: reminderDate,
            isPrivate: isPrivate,
            tags: tags
        )
        
        modelContext.insert(prayer)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewPrayerRequestView()
    }
} 