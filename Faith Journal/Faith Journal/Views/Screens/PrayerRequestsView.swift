import SwiftUI
import SwiftData

struct PrayerRequestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerRequest.dateCreated, order: .reverse) private var prayers: [PrayerRequest]
    @State private var showingNewPrayer = false
    @State private var searchText = ""
    @State private var selectedFilter: PrayerRequest.PrayerStatus = .active
    
    var filteredPrayers: [PrayerRequest] {
        let statusFiltered = prayers.filter { prayer in
            selectedFilter == .active ? prayer.status != .archived : prayer.status == selectedFilter
        }
        
        if searchText.isEmpty {
            return statusFiltered
        }
        
        return statusFiltered.filter { prayer in
            prayer.title.localizedCaseInsensitiveContains(searchText) ||
            prayer.details.localizedCaseInsensitiveContains(searchText) ||
            prayer.category?.localizedCaseInsensitiveContains(searchText) == true ||
            prayer.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([PrayerRequest.PrayerStatus.active,
                               .inProgress,
                               .answered,
                               .archived], id: \.self) { status in
                            Button {
                                selectedFilter = status
                            } label: {
                                Text(status.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == status ? .blue : .secondary.opacity(0.2))
                                    .foregroundStyle(selectedFilter == status ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                
                // Prayer List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPrayers) { prayer in
                            NavigationLink {
                                PrayerRequestDetailView(prayer: prayer)
                            } label: {
                                PrayerRequestCard(prayer: prayer) {
                                    // Handle tap if needed
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Prayer Requests")
            .searchable(text: $searchText, prompt: "Search prayers...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewPrayer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingNewPrayer) {
                NavigationStack {
                    NewPrayerRequestView()
                }
            }
        }
    }
}

struct PrayerRequestDetailView: View {
    let prayer: PrayerRequest
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingStatusSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(prayer.dateCreated.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if prayer.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Status
                Button {
                    showingStatusSheet = true
                } label: {
                    Text(prayer.status.rawValue)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.2))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
                
                // Details
                Text(prayer.details)
                    .font(.body)
                
                // Category if available
                if let category = prayer.category {
                    Label(category, systemImage: "folder.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Reminder if set
                if let reminderDate = prayer.reminderDate {
                    Label {
                        Text(reminderDate.formatted(date: .long, time: .shortened))
                    } icon: {
                        Image(systemName: "bell.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                // Answer date if available
                if let answerDate = prayer.dateAnswered {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prayer Answered")
                            .font(.headline)
                        Text(answerDate.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Tags
                if !prayer.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(prayer.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(prayer.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") {
                        // Handle edit
                    }
                    
                    Button("Share") {
                        // Handle share
                    }
                    
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Prayer Request", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(prayer)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this prayer request? This action cannot be undone.")
        }
        .confirmationDialog("Update Status", isPresented: $showingStatusSheet) {
            ForEach(PrayerRequest.PrayerStatus.allCases, id: \.self) { status in
                Button(status.rawValue) {
                    prayer.status = status
                    if status == .answered {
                        prayer.dateAnswered = Date()
                    }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch prayer.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .inProgress:
            return .orange
        case .archived:
            return .gray
        }
    }
}

#Preview {
    PrayerRequestsView()
} 