import SwiftUI

@available(iOS 17.0, *)
struct MoreView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var nav: AppNavigation
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var navigateToBible = false
    @State private var showingSettings = false
    @State private var showingBibleView = false
    @State private var showingBibleStudy = false
    @State private var showingLiveSessions = false
    @State private var showingMoodAnalytics = false
    @State private var showingReadingPlans = false
    @State private var showingStatistics = false
    @State private var showingGlobalSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background that extends to all edges
                Color(.systemGroupedBackground)
                    .ignoresSafeArea(.all, edges: .all)
                
                List {
                // Features Section
                Section(header: Text("Features")) {
                    NavigationLink {
                        BibleView()
                    } label: {
                        MenuRowContent(
                            icon: "book.closed.fill",
                            title: "Bible",
                            color: .purple
                        )
                    }
                    
                    NavigationLink {
                        BibleStudyView()
                    } label: {
                        MenuRowContent(
                            icon: "book.pages.fill",
                            title: "Bible Study",
                            color: .blue
                        )
                    }
                    
                    NavigationLink {
                        BibleStudyGameView()
                    } label: {
                        MenuRowContent(
                            icon: "gamecontroller.fill",
                            title: "Bible Game",
                            color: .purple
                        )
                    }
                    
                    NavigationLink {
                        LiveSessionsView()
                    } label: {
                        MenuRowContent(
                            icon: "person.3.fill",
                            title: "Live Sessions",
                            color: .orange
                        )
                    }
                    
                    NavigationLink {
                        MoodAnalyticsView()
                    } label: {
                        MenuRowContent(
                            icon: "chart.bar.fill",
                            title: "Mood Analytics",
                            color: .pink
                        )
                    }
                    
                    NavigationLink {
                        ReadingPlansView()
                    } label: {
                        MenuRowContent(
                            icon: "calendar",
                            title: "Reading Plans",
                            color: .green
                        )
                    }
                    
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        MenuRowContent(
                            icon: "chart.pie.fill",
                            title: "Statistics",
                            color: .purple
                        )
                    }
                    
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        MenuRowContent(
                            icon: "magnifyingglass",
                            title: "Global Search",
                            color: .blue
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
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToBible) {
                BibleView()
            }
            .onChange(of: nav.bibleTarget) { oldValue, newValue in
                // When a bible target is set and we're on the More tab, automatically navigate to Bible view
                if newValue != nil && selectedTab == 4 && !navigateToBible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        navigateToBible = true
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // When switching to More tab, check if there's a pending bible target
                if newValue == 4 && nav.bibleTarget != nil && !navigateToBible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToBible = true
                    }
                }
            }
            .onAppear {
                // If there's a pending bible target, navigate to Bible view
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

