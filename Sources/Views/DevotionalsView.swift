import SwiftUI
import SwiftData

struct DevotionalsView: View {
    @Query(sort: [SortDescriptor(\Devotional.date, order: .reverse)]) var devotionals: [Devotional]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            List {
                ForEach(devotionals) { devotional in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(devotional.title)
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
                            Spacer()
                            Button(action: {
                                devotional.isFavorite.toggle()
                                try? modelContext.save()
                            }) {
                                Image(systemName: devotional.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(devotional.content)
                            .font(.body)
                            .lineLimit(2)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text("by \(devotional.author)")
                            .font(.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text(devotional.date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Devotionals")
        }
    }
} 