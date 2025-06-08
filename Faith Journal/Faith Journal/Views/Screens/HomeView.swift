import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recentJournalEntries: [JournalEntry]
    @Query private var recentPrayerRequests: [PrayerRequest]
    @Query private var recentDevotionals: [Devotional]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Overview
                    HStack {
                        StatCard(title: "Journal Entries", count: recentJournalEntries.count, icon: "book.fill")
                        StatCard(title: "Active Prayers", count: recentPrayerRequests.filter { $0.status == .active }.count, icon: "hands.sparkles.fill")
                        StatCard(title: "Devotionals", count: recentDevotionals.count, icon: "text.book.closed.fill")
                    }
                    .padding(.horizontal)
                    
                    // Recent Journal Entries
                    VStack(alignment: .leading) {
                        SectionHeader(title: "Recent Journal Entries", icon: "book.fill")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentJournalEntries.prefix(5)) { entry in
                                    JournalEntryCard(entry: entry) {
                                        // Handle tap
                                    }
                                    .frame(width: 300)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Active Prayer Requests
                    VStack(alignment: .leading) {
                        SectionHeader(title: "Active Prayers", icon: "hands.sparkles.fill")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentPrayerRequests.filter { $0.status == .active }.prefix(5)) { prayer in
                                    PrayerRequestCard(prayer: prayer) {
                                        // Handle tap
                                    }
                                    .frame(width: 300)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent Devotionals
                    VStack(alignment: .leading) {
                        SectionHeader(title: "Recent Devotionals", icon: "text.book.closed.fill")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentDevotionals.prefix(5)) { devotional in
                                    DevotionalCard(devotional: devotional) {
                                        // Handle tap
                                    }
                                    .frame(width: 300)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Faith Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Open quick add menu
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
            
            NavigationLink {
                // Navigate to full list
            } label: {
                Text("See All")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
} 