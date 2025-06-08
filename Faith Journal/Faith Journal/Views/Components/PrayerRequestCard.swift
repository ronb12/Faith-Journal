import SwiftUI

struct PrayerRequestCard: View {
    let prayer: PrayerRequest
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(prayer.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if prayer.isPrivate {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(prayer.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(prayer.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let category = prayer.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !prayer.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(prayer.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(prayer.dateCreated.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let reminderDate = prayer.reminderDate {
                        Spacer()
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.secondary)
                        Text(reminderDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch prayer.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .inProgress:
            return .orange
        case .archived:
            return .gray
        }
    }
}

#Preview {
    PrayerRequestCard(
        prayer: PrayerRequest(
            title: "Family Health",
            details: "Praying for healing and protection for my family...",
            status: .active,
            category: "Health",
            tags: ["family", "health", "protection"]
        ),
        onTap: {}
    )
    .padding()
} 