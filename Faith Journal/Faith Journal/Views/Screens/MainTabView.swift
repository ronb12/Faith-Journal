import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(1)
            
            DevotionalsView()
                .tabItem {
                    Label("Devotionals", systemImage: "text.book.closed.fill")
                }
                .tag(2)
            
            PrayerRequestsView()
                .tabItem {
                    Label("Prayers", systemImage: "hands.sparkles.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    MainTabView()
} 