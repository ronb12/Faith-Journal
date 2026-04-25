import SwiftUI
import SwiftData
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@available(iOS 17.0, macOS 14.0, *)
struct MoreView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var nav: AppNavigation
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @Query private var userProfiles: [UserProfile]
    @ObservedObject private var firebaseSync = FirebaseSyncService.shared

    /// Use theme background in light mode; system background in dark mode to avoid white shadow/panel.
    private var contentBackground: Color {
        colorScheme == .dark ? Color.platformSystemGroupedBackground : themeManager.colors.background
    }
    @State private var navigateToBible = false
    @State private var showFaithFriendsFromNotification = false
    @State private var showingSettings = false
    @State private var showingBibleView = false
    @State private var showingBibleStudy = false
    @State private var showingLiveSessions = false
    @State private var showingReadingPlans = false
    @State private var showingStatistics = false
    @State private var showingGlobalSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Theme in light mode; system grouped in dark mode (avoids white shadow)
                contentBackground
                    #if os(macOS)
                    .ignoresSafeArea(.all, edges: [.bottom, .leading, .trailing])
                    #else
                    .ignoresSafeArea(.all, edges: .all)
                    #endif
                
                List {
                if firebaseSync.pendingFriendRequestCount > 0 {
                    Section {
                        Button {
                            showFaithFriendsFromNotification = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(themeManager.colors.primary)
                                Text(firebaseSync.pendingFriendRequestCount == 1 ? "You have 1 friend request" : "You have \(firebaseSync.pendingFriendRequestCount) friend requests")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                // Features Section
                Section(header: Text("Features")) {
                    NavigationLink {
                        BibleView()
                    } label: {
                        MenuRowContent(
                            icon: "book.closed.fill",
                            title: "Bible",
                            color: themeManager.colors.primary
                        )
                    }
                    
                    NavigationLink {
                        BibleStudyView()
                    } label: {
                        MenuRowContent(
                            icon: "book.pages.fill",
                            title: "Bible Study",
                            color: themeManager.colors.secondary
                        )
                    }

                    NavigationLink {
                        BibleStudyGameView()
                    } label: {
                        MenuRowContent(
                            icon: "gamecontroller.fill",
                            title: "Bible Game",
                            color: themeManager.colors.primary
                        )
                    }
                    
                    NavigationLink {
                        LiveSessionsView()
                    } label: {
                        MenuRowContent(
                            icon: "person.3.fill",
                            title: "Live Sessions",
                            color: themeManager.colors.accent
                        )
                    }

                    NavigationLink {
                        FaithFriendsView()
                    } label: {
                        MenuRowContent(
                            icon: "person.2.fill",
                            title: "Faith Friends",
                            color: themeManager.colors.primary
                        )
                    }
                    
                    NavigationLink {
                        MoodAnalyticsView()
                    } label: {
                        MenuRowContent(
                            icon: "chart.bar.fill",
                            title: "Mood Analytics",
                            color: themeManager.colors.accent
                        )
                    }
                    
                    NavigationLink {
                        ReadingPlansView()
                    } label: {
                        MenuRowContent(
                            icon: "calendar",
                            title: "Reading Plans",
                            color: themeManager.colors.secondary
                        )
                    }
                    
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        MenuRowContent(
                            icon: "chart.pie.fill",
                            title: "Statistics",
                            color: themeManager.colors.primary
                        )
                    }
                    
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        MenuRowContent(
                            icon: "magnifyingglass",
                            title: "Global Search",
                            color: themeManager.colors.secondary
                        )
                    }
                }
                
                // Settings Section
                Section(header: Text("Settings")) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        MenuRowContent(
                            icon: "gearshape.fill",
                            title: "Settings",
                            color: .gray
                        )
                    }
                }

                #if os(macOS)
                // Window: reopen main window (App Store Guideline 4)
                Section(header: Text("Window")) {
                    Button {
                        openWindow(id: "main")
                    } label: {
                        MenuRowContent(
                            icon: "macwindow.badge.plus",
                            title: "Show Main Window",
                            color: .blue
                        )
                    }
                }
                #endif

                // Build / Debug Section (helps confirm you’re running the latest binary)
                Section(header: Text("Build")) {
                    HStack {
                        MenuRowContent(
                            icon: "hammer.fill",
                            title: "Stamp",
                            color: .secondary
                        )
                        Spacer()
                        Text(BuildInfo.stamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    .accessibilityLabel("Build stamp \(BuildInfo.stamp)")
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("More")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            #if os(iOS)
            .toolbarBackground(contentBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .navigationDestination(isPresented: $navigateToBible) {
                BibleView()
            }
            .onChange(of: nav.bibleTarget) { oldValue, newValue in
                if newValue != nil && selectedTab == 4 && !navigateToBible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        navigateToBible = true
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 && nav.bibleTarget != nil && !navigateToBible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToBible = true
                    }
                }
            }
            .onChange(of: nav.navigateToFaithFriends) { oldValue, newValue in
                if newValue {
                    showFaithFriendsFromNotification = true
                    nav.navigateToFaithFriends = false
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showFaithFriendsFromNotification) {
                FaithFriendsView()
            }
            #elseif os(macOS)
            .sheet(isPresented: $showFaithFriendsFromNotification) {
                FaithFriendsView()
                    .macOSSheetFrameStandard()
            }
            #endif
            .onAppear {
                Task { await firebaseSync.refreshPendingFriendRequestCount() }
                if nav.bibleTarget != nil && !navigateToBible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        navigateToBible = true
                    }
                }
            }
        }
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            MenuRowContent(icon: icon, title: title, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MenuRowContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
            }
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        MoreView(selectedTab: .constant(0))
    }
}

