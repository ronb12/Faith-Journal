import SwiftUI
import SwiftData
import UIKit

@available(iOS 17.0, *)
struct ContentView: View {
    @EnvironmentObject private var nav: AppNavigation
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingNewJournalEntry = false
    @State private var showingNewPrayerRequest = false
    @State private var showingMoodCheckin = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea(.all, edges: .all)
            
            TabView(selection: $nav.selectedTab) {
                HomeView(
                    selectedTab: $nav.selectedTab,
                    showingNewJournalEntry: $showingNewJournalEntry,
                    showingNewPrayerRequest: $showingNewPrayerRequest,
                    showingMoodCheckin: $showingMoodCheckin,
                    showingAlert: $showingAlert,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                
                JournalView()
                    .tabItem {
                        Label("Journal", systemImage: "book.fill")
                    }
                    .tag(1)
                
                PrayerView()
                    .tabItem {
                        Label("Prayer", systemImage: "hands.sparkles.fill")
                    }
                    .tag(2)
                
                DevotionalsView(devotionalManager: DevotionalManager.shared)
                    .tabItem {
                        Label("Devotionals", systemImage: "heart.fill")
                    }
                    .tag(3)
                
                MoreView(selectedTab: $nav.selectedTab)
                    .environmentObject(nav)
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .accentColor(themeManager.colors.primary)
            .toolbar(.visible, for: .tabBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
        .onAppear {
            // Set tab bar appearance to match background
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGroupedBackground
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            // Clear badge when main content view appears - thread safe
            Task { @MainActor in
                NotificationService.shared.clearBadge()
            }
            // Pre-load devotionals in the background for faster access
            Task { @MainActor in
                DevotionalManager.shared.loadDevotionals()
            }
        }
        .onChange(of: nav.selectedTab) { oldValue, newValue in
            // Pre-load devotionals when user switches to devotionals tab
            if newValue == 3 {
                Task { @MainActor in
                    DevotionalManager.shared.loadDevotionals()
                }
            }
        }
        .sheet(isPresented: $showingNewJournalEntry) {
            NewJournalEntryView()
        }
        .sheet(isPresented: $showingNewPrayerRequest) {
            NewPrayerRequestView()
        }
        .sheet(isPresented: $showingMoodCheckin) {
            MoodCheckinView()
        }
        .alert("Quick Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - MoreView

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 17.0, *) {
            ContentView()
                .environmentObject(AppNavigation())
                .modelContainer(for: [JournalEntry.self, PrayerRequest.self, MoodEntry.self], inMemory: true)
        }
    }
}
