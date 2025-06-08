import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
            
            BibleStudyView()
                .tabItem {
                    Label("Bible", systemImage: "book.closed.fill")
                }
            
            PrayerView()
                .tabItem {
                    Label("Prayer", systemImage: "hands.sparkles.fill")
                }
            
            CreativeView()
                .tabItem {
                    Label("Create", systemImage: "paintbrush.fill")
                }
            
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
} 