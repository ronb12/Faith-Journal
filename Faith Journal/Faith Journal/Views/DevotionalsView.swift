import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct DevotionalsView: View {
    let devotionalManager: Any
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedDevotional: Devotional?
    @State private var showingDetail = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if #available(iOS 17.0, *), let devotionalManager = devotionalManager as? DevotionalManager {
            DevotionalsContentView(manager: devotionalManager, selectedDevotional: $selectedDevotional)
                .onAppear {
                    devotionalManager.setModelContext(modelContext)
                }
        } else {
            Text("Devotionals are only available on iOS 17+")
        }
    }
}

@available(iOS 17.0, *)
private struct DevotionalsContentView: View {
    @ObservedObject var manager: DevotionalManager
    @Binding var selectedDevotional: Devotional?
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    
    // Detect if running on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        themeManager.colors.primary.opacity(0.1),
                        themeManager.colors.secondary.opacity(0.05),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Today's Devotional Card
                        if let todaysDevotional = manager.getTodaysDevotional() {
                            todayDevotionalCard(devotional: todaysDevotional, manager: manager)
                        }
                        
                        // Category Filter
                        categoryFilterSection(manager: manager)
                        
                        // All Devotionals List
                        allDevotionalsSection(manager: manager)
                    }
                    .padding(isIPad ? 40 : 16)
                }
            }
            .navigationTitle("Devotionals")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                // Ensure modelContext is set before loading
                if manager.modelContext == nil {
                    // This will be set by the parent view, but ensure it's set
                    manager.setModelContext(modelContext)
                }
                // Start loading devotionals immediately when view appears
                manager.loadDevotionals()
            }
            .sheet(item: $selectedDevotional) { devotional in
                DevotionalDetailView(devotional: devotional, manager: manager)
            }
        }
    }
    
    @ViewBuilder
    private func todayDevotionalCard(devotional: Devotional, manager: DevotionalManager) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.colors.primary, themeManager.colors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Devotional")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(devotional.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Get current state from observed manager
                let currentDevotional = manager.devotionals.first { $0.id == devotional.id } ?? devotional
                Button(action: {
                    manager.markAsCompleted(devotional)
                }) {
                    Image(systemName: currentDevotional.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(currentDevotional.isCompleted ? .green : .primary)
                        .font(.title3)
                }
            }
            
            Divider()
            
            Text(devotional.title)
                .font(.title2)
                .font(.body.weight(.bold))
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.caption)
                Text(devotional.scripture)
                    .font(.subheadline)
                    .foregroundColor(themeManager.colors.primary)
                    .font(.body.weight(.medium))
                    .italic()
            }
            
            Text(devotional.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(4)
                .lineSpacing(4)
            
            Button(action: {
                // Get current devotional from manager
                let currentDevotional = manager.devotionals.first { $0.id == devotional.id } ?? devotional
                selectedDevotional = currentDevotional
            }) {
                HStack {
                    Text("Read Full Devotional")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [themeManager.colors.primary, themeManager.colors.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    @ViewBuilder
    private func categoryFilterSection(manager: DevotionalManager) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                HStack(spacing: 12) {
                    ForEach(manager.categories, id: \.self) { category in
                        Button(action: {
                            manager.selectedCategory = category
                        }) {
                            Text(category)
                                .font(.subheadline)
                                .font(.body.weight(.medium))
                                .foregroundColor(manager.selectedCategory == category ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    manager.selectedCategory == category ?
                                    LinearGradient(colors: [themeManager.colors.primary, themeManager.colors.secondary], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func allDevotionalsSection(manager: DevotionalManager) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Devotionals")
                    .font(.title2)
                    .font(.body.weight(.bold))
                    .foregroundColor(.primary)
                Spacer()
                if manager.isLoading {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(manager.devotionals.count) devotionals")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            if manager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading devotionals...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let filtered = manager.filteredDevotionals()
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.primary.opacity(0.5))
                        Text("No devotionals found in this category.")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { devotional in
                            // Get current devotional state from manager
                            let currentDevotional = manager.devotionals.first { $0.id == devotional.id } ?? devotional
                            DevotionalRow(devotional: currentDevotional) {
                                selectedDevotional = currentDevotional
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DevotionalRow: View {
    let devotional: Devotional
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Category indicator
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.primary.opacity(0.8), themeManager.colors.secondary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(devotional.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if devotional.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .foregroundColor(themeManager.colors.primary)
                            .font(.caption2)
                        Text(devotional.scripture)
                            .font(.subheadline)
                            .foregroundColor(themeManager.colors.primary)
                            .font(.body.weight(.medium))
                            .italic()
                    }
                    
                    Text(devotional.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .lineSpacing(2)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(devotional.author)
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(devotional.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Text("•")
                            .foregroundColor(.primary)
                        
                        Text(devotional.category)
                            .font(.caption)
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [themeManager.colors.primary.opacity(0.7), themeManager.colors.secondary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.primary)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 17.0, *)
struct DevotionalDetailView: View {
    let devotional: Devotional
    @ObservedObject var manager: DevotionalManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Get the current state of the devotional from the manager
    private var currentDevotional: Devotional? {
        manager.devotionals.first { $0.id == devotional.id }
    }
    
    private var isCompleted: Bool {
        currentDevotional?.isCompleted ?? devotional.isCompleted
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(devotional.title)
                        .font(.title)
                        .font(.body.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text(devotional.scripture)
                        .font(.title3)
                        .foregroundColor(themeManager.colors.primary)
                        .italic()
                    
                    Text(devotional.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                    
                    HStack {
                        Text("by \(devotional.author)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(devotional.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Text(devotional.category)
                        .font(.caption)
                        .foregroundColor(themeManager.colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.colors.primary.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Devotional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        manager.markAsCompleted(devotional)
                    }) {
                        HStack {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            Text(isCompleted ? "Mark as Unread" : "Mark as Read")
                        }
                        .foregroundColor(isCompleted ? .green : themeManager.colors.primary)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Save button (bookmark) - always visible
                    Button(action: {
                        manager.toggleFavorite(devotional)
                    }) {
                        let isFavorite = currentDevotional?.isFavorite ?? devotional.isFavorite
                        Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isFavorite ? .purple : themeManager.colors.primary)
                    }
                    Button("Done") {
                        RewardedInterstitialManager.shared.tryShowAd { dismiss() }
                    }
                }
            }
        }
    }
}