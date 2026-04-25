import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct ContentView: View {
    @EnvironmentObject private var nav: AppNavigation
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @Query private var userProfiles: [UserProfile]
    @State private var showingNewJournalEntry = false
    @State private var showingNewPrayerRequest = false
    @State private var showingMoodCheckin = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    /// Use theme background in light mode; system background in dark mode to avoid white shadow/panel.
    private var contentBackground: Color {
        colorScheme == .dark ? Color.platformSystemGroupedBackground : themeManager.colors.background
    }

    var body: some View {
        ZStack {
            contentBackground
                .ignoresSafeArea(.all, edges: .all)
            
            VStack(spacing: 0) {
                #if os(iOS)
                BannerAdView()
                    .frame(height: 60)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(contentBackground)
                #endif
                
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
                #if os(iOS)
                .toolbar(.visible, for: .tabBar)
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: [.bottom])
        .onAppear {
            #if os(iOS)
            // Set tab bar appearance to match background
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGroupedBackground
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            #endif
            // Clear badge when main content view appears - thread safe
            Task { @MainActor in
                NotificationService.shared.clearBadge()
            }
            // Pre-load devotionals in the background for faster access
            Task { @MainActor in
                DevotionalManager.shared.loadDevotionals()
            }
            #if os(iOS)
            // Pre-load rewarded interstitial for natural break points
            RewardedInterstitialManager.shared.loadAd()
            #endif
        }
        .onChange(of: nav.selectedTab) { oldValue, newValue in
            // Pre-load devotionals when user switches to devotionals tab
            if newValue == 3 {
                Task { @MainActor in
                    DevotionalManager.shared.loadDevotionals()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToFaithFriends"))) { _ in
            nav.selectedTab = 4
            nav.navigateToFaithFriends = true
        }
        .sheet(isPresented: $showingNewJournalEntry) {
            NewJournalEntryView()
                .macOSSheetFrameForm()
        }
        .sheet(isPresented: $showingNewPrayerRequest) {
            NewPrayerRequestView()
                .macOSSheetFrameForm()
        }
        .sheet(isPresented: $showingMoodCheckin) {
            MoodCheckinView()
                .macOSSheetFrameForm()
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
                .modelContainer(for: [JournalEntry.self, PrayerRequest.self, MoodEntry.self], inMemory: true)
        }
    }
}
