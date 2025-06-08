import SwiftUI

struct PrayerView: View {
    @State private var showingNewPrayer = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Requests").tag(0)
                    Text("Answered").tag(1)
                    Text("Statistics").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    PrayerRequestsView()
                        .tag(0)
                    
                    AnsweredPrayersView()
                        .tag(1)
                    
                    PrayerStatsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Prayer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPrayer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPrayer) {
                NewPrayerRequestView()
            }
        }
    }
}

struct PrayerRequestsView: View {
    var body: some View {
        List {
            Section("Active Requests") {
                Text("Your active prayer requests will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Prayer Chain") {
                Text("Group prayer requests will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AnsweredPrayersView: View {
    var body: some View {
        List {
            Text("Your answered prayers will appear here")
                .foregroundStyle(.secondary)
        }
    }
}

struct PrayerStatsView: View {
    var body: some View {
        List {
            Section("Overview") {
                Text("Total Prayers: 0")
                Text("Answered: 0")
                Text("Active: 0")
            }
            
            Section("Categories") {
                Text("Prayer categories will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewPrayerRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var isPrivate = false
    @State private var selectedCategory: PrayerCategory?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select a category").tag(nil as PrayerCategory?)
                        ForEach(PrayerCategory.allCases) { category in
                            Text(category.rawValue).tag(category as PrayerCategory?)
                        }
                    }
                    
                    Toggle("Private Request", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save prayer request
                        dismiss()
                    }
                }
            }
        }
    }
}

enum PrayerCategory: String, CaseIterable, Identifiable {
    case personal = "Personal"
    case family = "Family"
    case health = "Health"
    case financial = "Financial"
    case spiritual = "Spiritual"
    case relationships = "Relationships"
    case work = "Work"
    case other = "Other"
    
    var id: String { rawValue }
}

#Preview {
    PrayerView()
} 