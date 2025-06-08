import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var showingNewEntry = false
    @State private var searchText = ""
    
    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.content.localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            JournalEntryDetailView(entry: entry)
                        } label: {
                            JournalEntryCard(entry: entry) {
                                // Handle tap if needed
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Journal")
            .searchable(text: $searchText, prompt: "Search entries...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Date: Newest First") {
                            // Implement sorting
                        }
                        Button("Date: Oldest First") {
                            // Implement sorting
                        }
                        Button("Title: A-Z") {
                            // Implement sorting
                        }
                        Button("Title: Z-A") {
                            // Implement sorting
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NavigationStack {
                    NewJournalEntryView()
                }
            }
        }
    }
}

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(entry.date.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if entry.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Content
                Text(entry.content)
                    .font(.body)
                
                // Mood if available
                if let mood = entry.mood {
                    HStack {
                        Label(mood, systemImage: "heart.fill")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                // Bible reference if available
                if let reference = entry.bibleReference {
                    Text(reference)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                // Prayer points if available
                if !entry.prayerPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prayer Points")
                            .font(.headline)
                        
                        ForEach(entry.prayerPoints, id: \.self) { point in
                            Label(point, systemImage: "circle.fill")
                                .font(.subheadline)
                        }
                    }
                }
                
                // Tags
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                // Media previews
                if entry.imageData != nil || entry.audioURL != nil || entry.drawingData != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attachments")
                            .font(.headline)
                        
                        HStack {
                            if entry.imageData != nil {
                                Label("Photo", systemImage: "photo.fill")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            if entry.audioURL != nil {
                                Label("Audio", systemImage: "waveform")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            if entry.drawingData != nil {
                                Label("Drawing", systemImage: "pencil.tip")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(entry.title)
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
        .alert("Delete Entry", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
}

#Preview {
    JournalView()
} 