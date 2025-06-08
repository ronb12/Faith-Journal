import SwiftUI
import Charts

struct AnalyticsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Prayer").tag(1)
                    Text("Bible").tag(2)
                    Text("Journal").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    OverviewView()
                        .tag(0)
                    
                    PrayerAnalyticsView()
                        .tag(1)
                    
                    BibleAnalyticsView()
                        .tag(2)
                    
                    JournalAnalyticsView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Insights")
        }
    }
}

struct OverviewView: View {
    var body: some View {
        List {
            Section("Faith Journey") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Streak: 0 days")
                    Text("Total Prayers: 0")
                    Text("Bible Reading: 0%")
                    Text("Journal Entries: 0")
                }
            }
            
            Section("Achievements") {
                Text("Your achievements will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PrayerAnalyticsView: View {
    var body: some View {
        List {
            Section("Prayer Statistics") {
                Text("Prayer analytics will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Categories") {
                Text("Prayer category breakdown will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BibleAnalyticsView: View {
    var body: some View {
        List {
            Section("Reading Progress") {
                Text("Bible reading statistics will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Memorization") {
                Text("Verse memorization progress will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct JournalAnalyticsView: View {
    var body: some View {
        List {
            Section("Writing Habits") {
                Text("Journal writing statistics will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Mood Trends") {
                Text("Mood tracking analytics will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AnalyticsView()
} 