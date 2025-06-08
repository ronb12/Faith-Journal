import SwiftUI

struct CommunityView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Groups").tag(0)
                    Text("Prayer").tag(1)
                    Text("Share").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    GroupsView()
                        .tag(0)
                    
                    PrayerGroupsView()
                        .tag(1)
                    
                    ShareView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Community")
        }
    }
}

struct GroupsView: View {
    var body: some View {
        List {
            Section("My Groups") {
                Text("Your groups will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Discover") {
                Text("Suggested groups will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PrayerGroupsView: View {
    var body: some View {
        List {
            Section("Prayer Chains") {
                Text("Active prayer chains will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Prayer Partners") {
                Text("Your prayer partners will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ShareView: View {
    var body: some View {
        List {
            Section("Devotionals") {
                Text("Shared devotionals will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Discussions") {
                Text("Verse discussions will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    CommunityView()
} 