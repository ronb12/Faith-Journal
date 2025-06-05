import SwiftUI
import SwiftData

struct DevotionalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Devotional.date, order: .reverse) private var devotionals: [Devotional]
    @State private var showingNewDevotional = false
    @State private var searchText = ""
    
    var filteredDevotionals: [Devotional] {
        if searchText.isEmpty {
            return devotionals
        }
        return devotionals.filter { devotional in
            devotional.title.localizedCaseInsensitiveContains(searchText) ||
            devotional.scripture.localizedCaseInsensitiveContains(searchText) ||
            devotional.reflection.localizedCaseInsensitiveContains(searchText) ||
            devotional.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredDevotionals) { devotional in
                        NavigationLink {
                            DevotionalDetailView(devotional: devotional)
                        } label: {
                            DevotionalCard(devotional: devotional) {
                                // Handle tap if needed
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Devotionals")
            .searchable(text: $searchText, prompt: "Search devotionals...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewDevotional = true
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
            .sheet(isPresented: $showingNewDevotional) {
                NavigationStack {
                    NewDevotionalView()
                }
            }
        }
    }
}

struct DevotionalDetailView: View {
    let devotional: Devotional
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(devotional.date.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if devotional.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Scripture
                Text(devotional.scripture)
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                // Reflection
                Text(devotional.reflection)
                    .font(.body)
                
                // Mood if available
                if let mood = devotional.mood {
                    HStack {
                        Label(mood, systemImage: "heart.fill")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                // Related verses
                if !devotional.relatedVerses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Verses")
                            .font(.headline)
                        
                        ForEach(devotional.relatedVerses, id: \.self) { verse in
                            Text(verse)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Prayer points
                if !devotional.prayerPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prayer Points")
                            .font(.headline)
                        
                        ForEach(devotional.prayerPoints, id: \.self) { point in
                            Label(point, systemImage: "circle.fill")
                                .font(.subheadline)
                        }
                    }
                }
                
                // Tags
                if !devotional.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(devotional.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                // Media previews
                if devotional.imageData != nil || devotional.audioURL != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attachments")
                            .font(.headline)
                        
                        HStack {
                            if devotional.imageData != nil {
                                Label("Photo", systemImage: "photo.fill")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            if devotional.audioURL != nil {
                                Label("Audio", systemImage: "waveform")
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
        .navigationTitle(devotional.title)
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
        .alert("Delete Devotional", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(devotional)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this devotional? This action cannot be undone.")
        }
    }
}

#Preview {
    DevotionalsView()
} 