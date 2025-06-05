import SwiftUI

struct DevotionalCard: View {
    let devotional: Devotional
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(devotional.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if devotional.isPrivate {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(devotional.scripture)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .lineLimit(2)
                
                Text(devotional.reflection)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if let mood = devotional.mood {
                        Text(mood)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text(devotional.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !devotional.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(devotional.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DevotionalCard(
        devotional: Devotional(
            title: "Morning Devotion",
            scripture: "Philippians 4:13",
            reflection: "Reflecting on God's strength in my life...",
            tags: ["strength", "faith", "morning"],
            mood: "Inspired"
        ),
        onTap: {}
    )
    .padding()
} 