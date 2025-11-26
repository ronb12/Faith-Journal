import SwiftUI
import SwiftData

struct HomeView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var bibleVerseManager = BibleVerseOfTheDayManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Bible Verse of the Day
                if let verse = bibleVerseManager.currentVerse {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bible Verse of the Day")
                            .font(.headline)
                            .foregroundColor(themeManager.colors.primary)
                        Text(verse.verse)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.colors.text)
                        Text("- \(verse.reference) (\(verse.translation))")
                            .font(.subheadline)
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                    .padding()
                    .background(themeManager.colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(radius: 4)
                }
                // Quick Links
                HStack(spacing: 16) {
                    FeatureCard(icon: "book.fill", label: "Journal", color: themeManager.colors.primary)
                    FeatureCard(icon: "hands.sparkles.fill", label: "Prayer", color: themeManager.colors.accent)
                    FeatureCard(icon: "heart.fill", label: "Devotionals", color: themeManager.colors.secondary)
                }
                .padding(.horizontal)
                // Welcome
                Text("Welcome to Faith Journal! Start your day with inspiration, reflection, and prayer.")
                    .font(.body)
                    .foregroundColor(themeManager.colors.textSecondary)
                    .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(themeManager.colors.background.ignoresSafeArea())
        .onAppear {
            bibleVerseManager.loadTodaysVerse(context: modelContext)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let label: String
    let color: Color
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding()
                .background(color)
                .clipShape(Circle())
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(width: 90, height: 120)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(radius: 3)
    }
} 