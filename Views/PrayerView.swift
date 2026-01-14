import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import Speech
import UserNotifications

@available(iOS 17.0, *)
struct PrayerView: View {
    @Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) var requests: [PrayerRequest]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewRequest = false
    @State private var searchText = ""
    @State private var selectedFilter: PrayerFilter = .all
    @State private var showingFilterSheet = false
    
    var filteredRequests: [PrayerRequest] {
        var filtered = requests
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { request in
                request.title.localizedCaseInsensitiveContains(searchText) ||
                request.details.localizedCaseInsensitiveContains(searchText) ||
                request.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .answered:
            filtered = filtered.filter { $0.status == .answered }
        case .archived:
            filtered = filtered.filter { $0.status == .archived }
        case .private:
            filtered = filtered.filter { $0.isPrivate }
        case .public:
            filtered = filtered.filter { !$0.isPrivate }
        }
        
        return filtered
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Search and Filter Bar
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.primary)
                            TextField("Search prayers...", text: $searchText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "All", isSelected: selectedFilter == .all) {
                                        selectedFilter = .all
                                    }
                                    FilterChip(title: "Active", isSelected: selectedFilter == .active) {
                                        selectedFilter = .active
                                    }
                                    FilterChip(title: "Answered", isSelected: selectedFilter == .answered) {
                                        selectedFilter = .answered
                                    }
                                    FilterChip(title: "Private", isSelected: selectedFilter == .private) {
                                        selectedFilter = .private
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    if filteredRequests.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Prayer Requests")
                                .font(.title2)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Begin your prayer journey by adding your first prayer request")
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: { showingNewRequest = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add First Prayer")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(themeManager.colors.primary)
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        // Prayer Requests List
                        List {
                            ForEach(filteredRequests) { request in
                                NavigationLink(destination: PrayerRequestDetailView(request: request)) {
                                    PrayerRequestRow(request: request)
                                }
                            }
                            .onDelete(perform: deleteRequest)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationTitle("Prayer Requests")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingNewRequest = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingNewRequest) {
                    NewPrayerRequestView()
                }
            }
            .onAppear {
                // Create sample data if no requests exist
                if requests.isEmpty {
                    createSamplePrayers()
                }
            }
        } else {
            Text("Prayer Requests are only available on iOS 17+")
        }
    }
    
    private func deleteRequest(at offsets: IndexSet) {
        var requestsToDelete: [PrayerRequest] = []
        for index in offsets {
            guard index < filteredRequests.count else { continue }
            let request = filteredRequests[index]
            requestsToDelete.append(request)
            modelContext.delete(request)
        }
        
        do {
            try modelContext.save()
            
            // Sync deletions to Firebase
            for request in requestsToDelete {
                Task {
                    await FirebaseSyncService.shared.deletePrayerRequest(request)
                    print("✅ [FIREBASE] Prayer request deletion synced to Firebase")
                }
            }
        } catch {
            print("❌ Error deleting prayer request: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.deleteFailed)
        }
    }
    
    private func createSamplePrayers() {
        let samplePrayers = [
            PrayerRequest(
                title: "Guidance for Career Decision",
                details: "I'm facing a major career decision and need God's wisdom to choose the right path. Please pray that I would clearly hear His voice and have the courage to follow where He leads.",
                tags: ["career", "guidance", "wisdom"],
                isPrivate: false
            ),
            PrayerRequest(
                title: "Healing for Family Member",
                details: "My mother is dealing with health issues and I'm praying for her complete healing. I trust in God's power to restore her health and bring peace to our family during this difficult time.",
                tags: ["healing", "family", "health"],
                isPrivate: true
            ),
            PrayerRequest(
                title: "Financial Provision",
                details: "We're facing some financial challenges and need God's provision. I'm praying for wisdom in managing our resources and for God to open doors of opportunity.",
                tags: ["finances", "provision", "trust"],
                isPrivate: false
            )
        ]
        
        // Make one prayer answered as an example (safely check array bounds)
        if !samplePrayers.isEmpty {
            samplePrayers[0].status = .answered
            samplePrayers[0].isAnswered = true
            samplePrayers[0].answerDate = Date().addingTimeInterval(-86400) // Yesterday
            samplePrayers[0].answerNotes = "God provided clear guidance through a conversation with a mentor. I feel confident about the direction He's leading me."
        }
        
        for prayer in samplePrayers {
            modelContext.insert(prayer)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error creating sample prayers: \(error.localizedDescription)")
            // Don't show error to user for sample data, just log it
        }
    }
}

@available(iOS 17.0, *)
struct PrayerRequestRow: View {
    let request: PrayerRequest
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var statusColor: Color {
        switch request.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .archived:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.title)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primary)
                
                Spacer()
                
                if request.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.primary)
                        .font(.caption)
                }
                
                if request.isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(request.details)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.primary)
            
            HStack {
                Text(request.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(request.status.rawValue)
                    .font(.caption)
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            if !request.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(request.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.colors.primary.opacity(0.1))
                                .foregroundColor(themeManager.colors.primary)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

enum PrayerFilter {
    case all, active, answered, archived, `private`, `public`
}

// MARK: - Category Data Structure
struct PrayerCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

// MARK: - Priority Level
enum PrayerPriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle"
        case .medium: return "circle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Recurring Prayer Option
enum RecurringPrayer: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .daily: return "sunrise.fill"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        }
    }
}

@available(iOS 17.0, *)
struct NewPrayerRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // Optional request for editing mode
    let requestToEdit: PrayerRequest?
    
    // Core fields
    @State private var title = ""
    @State private var description = ""
    @State private var requestTags: [String] = []
    @State private var newTagText = ""
    @State private var isPrivate = false
    @State private var selectedCategory: String = ""
    @State private var requestDate: Date = Date()
    @State private var dateSelectionMode: DateSelectionMode = .today
    
    // Initialize for new request or edit mode
    init(request: PrayerRequest? = nil) {
        self.requestToEdit = request
    }
    
    // Priority and urgency
    @State private var priority: PrayerPriority = .medium
    
    // Prayer reminders
    @State private var enableReminder = false
    @State private var reminderTime = Date()
    @State private var reminderFrequency: ReminderFrequency = .daily
    
    // Additional features
    @State private var relatedBibleVerse: String = ""
    @State private var prayerPartners: [String] = []
    @State private var newPartnerText = ""
    @State private var suggestedPartners: [String] = []
    @State private var linkedJournalEntryId: UUID?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoURL: URL?
    @State private var photoImage: UIImage?
    @State private var recurringPrayer: RecurringPrayer = .none
    
    // Prayer templates
    @State private var showingTemplatePicker = false
    @State private var selectedTemplate: PrayerTemplate?
    
    // UI State
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var showingBibleVersePicker = false
    @State private var showingJournalEntryPicker = false
    @State private var isTranscribing = false
    @State private var showPrivateToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "lock.fill"
    
    // Voice-to-text
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine: AVAudioEngine?
    
    // Auto-save
    @State private var autoSaveTimer: Timer?
    @State private var hasUnsavedChanges = false
    
    // Categories with icons and colors
    let categories: [PrayerCategory] = [
        PrayerCategory(name: "Health", icon: "heart.fill", color: .red),
        PrayerCategory(name: "Family", icon: "person.2.fill", color: .blue),
        PrayerCategory(name: "Work", icon: "briefcase.fill", color: .orange),
        PrayerCategory(name: "Relationships", icon: "heart.circle.fill", color: .pink),
        PrayerCategory(name: "Spiritual Growth", icon: "book.fill", color: .purple),
        PrayerCategory(name: "Financial", icon: "dollarsign.circle.fill", color: .green),
        PrayerCategory(name: "Emotional", icon: "brain.head.profile", color: .indigo),
        PrayerCategory(name: "Other", icon: "ellipsis.circle.fill", color: .gray)
    ]
    
    enum DateSelectionMode {
        case today, yesterday, custom
    }
    
    enum ReminderFrequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case custom = "Custom"
    }
    
    // Quick prayer tags
    let prayerQuickTags = [
        "Urgent",
        "Ongoing",
        "Breakthrough",
        "Answered",
        "Healing",
        "Guidance",
        "Protection",
        "Provision",
        "Peace",
        "Strength",
        "Wisdom",
        "Salvation",
        "Restoration",
        "Gratitude",
        "Intercession",
        "Personal",
        "Family",
        "Community",
        "Ministry",
        "Mission",
        "Faith",
        "Hope",
        "Love",
        "Forgiveness",
        "Deliverance"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                scrollContentView
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(requestToEdit == nil ? "New Prayer Request" : "Edit Prayer Request")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Could show confirmation dialog
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveRequest) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(requestToEdit == nil ? "Save" : "Update")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSaving)
                }
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            PrayerTemplatePickerView(selectedTemplate: $selectedTemplate)
        }
        .sheet(isPresented: $showingBibleVersePicker) {
            BibleVersePickerView(selectedVerse: $relatedBibleVerse)
        }
        .sheet(isPresented: $showingJournalEntryPicker) {
            JournalEntryPickerView(selectedEntryId: $linkedJournalEntryId)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert(requestToEdit == nil ? "Prayer Request Saved" : "Prayer Request Updated", isPresented: $showingSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(requestToEdit == nil ? "Your prayer request has been saved successfully!" : "Your prayer request has been updated successfully!")
        }
        .onAppear {
            setupSpeechRecognizer()
            setupAutoSave()
            loadSuggestedPartners()
            
            // If editing, load request data
            if let request = requestToEdit {
                loadRequestForEditing(request)
            }
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadPhoto(from: newValue)
        }
        .onChange(of: selectedTemplate) { _, newValue in
            if let template = newValue {
                title = template.title
                description = template.description
                selectedCategory = template.category
            }
        }
        .onChange(of: isPrivate) { oldValue, newValue in
            // Show toast when privacy status changes
            if newValue != oldValue {
                if newValue {
                    toastMessage = "Prayer request is now private"
                    toastIcon = "lock.fill"
                } else {
                    toastMessage = "Prayer request is now public"
                    toastIcon = "lock.open.fill"
                }
                showPrivateToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showPrivateToast = false
                }
            }
            
            // Auto-save when privacy changes
            if !title.isEmpty && !description.isEmpty {
                hasUnsavedChanges = true
                Task {
                    await saveRequestImmediately()
                }
            } else {
                hasUnsavedChanges = true
                saveDraft()
            }
        }
        .overlay(
            // Toast Notification
            Group {
                if showPrivateToast {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: toastIcon)
                                .foregroundColor(.white)
                                .font(.title3)
                            Text(toastMessage)
                                .font(.subheadline)
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isPrivate ? Color.purple : Color.blue)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showPrivateToast)
                        Spacer()
                    }
                    .padding(.top, 60)
                }
            }
        )
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
    
    private var scrollContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                gradientHeader
                mainContentSection
            }
        }
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 20) {
            quickActionsSection
            titleCard
            descriptionCard
            categoryCard
            priorityCard
            tagsCard
            additionalFeaturesCard
            remindersCard
            privacyCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
    
    private var gradientHeader: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.8),
                Color.blue.opacity(0.9),
                Color.purple.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 120)
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("New Prayer Request")
                        .font(.title2)
                        .font(.body.weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        )
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Prayer Template Button
                Button(action: { showingTemplatePicker = true }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.yellow)
                        Text("Use Template")
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Quick Date Selection
                Menu {
                    Button(action: {
                        dateSelectionMode = .today
                        requestDate = Date()
                    }) {
                        Label("Today", systemImage: "calendar")
                    }
                    Button(action: {
                        dateSelectionMode = .yesterday
                        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                            requestDate = yesterday
                        }
                    }) {
                        Label("Yesterday", systemImage: "calendar.badge.clock")
                    }
                    Button(action: {
                        dateSelectionMode = .custom
                    }) {
                        Label("Custom Date", systemImage: "calendar")
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(dateSelectionMode == .today ? "Today" : dateSelectionMode == .yesterday ? "Yesterday" : "Custom")
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            if dateSelectionMode == .custom {
                    DatePicker("Request Date", selection: $requestDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding(.top, 20)
    }
    
    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.purple)
                Text("Prayer Title")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            TextField("What would you like to pray for?", text: $title)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("Description")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // Voice-to-Text Button
                Button(action: startVoiceToText) {
                    HStack(spacing: 4) {
                        Image(systemName: isTranscribing ? "waveform" : "mic.fill")
                            .font(.caption)
                        Text(isTranscribing ? "Listening..." : "Voice")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isTranscribing ? Color.red : Color.blue)
                    .cornerRadius(8)
                }
            }
            
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("What would you like to pray for? Share the details of your prayer request...")
                        .foregroundColor(.primary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $description)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Character count
            HStack {
                Spacer()
                Text("\(description.count) characters")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.purple)
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Visual Category Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category.name
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                Text(category.name)
                                    .font(.caption)
                                    .font(.body.weight(.medium))
                            }
                            .foregroundColor(selectedCategory == category.name ? .white : .primary)
                            .frame(width: 80, height: 80)
                            .background(selectedCategory == category.name ? category.color : Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCategory == category.name ? category.color : Color.clear, lineWidth: 3)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.purple)
                Text("Priority")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Priority Picker
            HStack(spacing: 12) {
                ForEach(PrayerPriority.allCases, id: \.self) { priorityLevel in
                    Button(action: {
                        priority = priorityLevel
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: priorityLevel.icon)
                                .font(.title3)
                            Text(priorityLevel.rawValue)
                                .font(.caption)
                                .font(.body.weight(.medium))
                        }
                        .foregroundColor(priority == priorityLevel ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(priority == priorityLevel ? priorityLevel.color : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.purple)
                Text("Tags")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Tag Chips
            if !requestTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(requestTags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.subheadline)
                                Button(action: {
                                    requestTags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .cornerRadius(16)
                        }
                    }
                }
            }
            
            // Add Tag Input
            HStack {
                TextField("Add a tag...", text: $newTagText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addTag()
                    }
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Quick Tag Buttons - Scrollable
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(prayerQuickTags, id: \.self) { quickTag in
                        Button(action: {
                            if !requestTags.contains(quickTag) {
                                requestTags.append(quickTag)
                            }
                        }) {
                            Text(quickTag)
                                .font(.caption)
                                .font(.body.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(requestTags.contains(quickTag) ? Color.purple.opacity(0.3) : Color(.systemGray5))
                                .foregroundColor(requestTags.contains(quickTag) ? .purple : .primary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(requestTags.contains(quickTag) ? Color.purple : Color.clear, lineWidth: 1.5)
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.purple)
                Text("Prayer Reminders")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Toggle("Enable Prayer Reminder", isOn: $enableReminder)
            
            if enableReminder {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You'll receive a notification to pray for this request")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prayer Reminder Time")
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prayer Reminder Frequency")
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Picker("Prayer Reminder Frequency", selection: $reminderFrequency) {
                            ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var additionalFeaturesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.purple)
                Text("Additional Features")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Bible Verse
            Button(action: { showingBibleVersePicker = true }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.purple)
                    Text(relatedBibleVerse.isEmpty ? "Add Bible Verse" : relatedBibleVerse)
                        .foregroundColor(relatedBibleVerse.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !relatedBibleVerse.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Prayer Partners Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                    Text("Prayer Partners")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // Helper text
                Text("Who are you praying with? Add names of people you're sharing this prayer request with for accountability and support.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Partner Chips
                if !prayerPartners.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(prayerPartners, id: \.self) { partner in
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.caption)
                                    Text(partner)
                                        .font(.subheadline)
                                    Button(action: {
                                        if let index = prayerPartners.firstIndex(of: partner) {
                                            prayerPartners.remove(at: index)
                                            hasUnsavedChanges = true
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }
                
                // Add Partner Input
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                    TextField("Add prayer partner name...", text: $newPartnerText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            addPrayerPartner()
                        }
                    Button(action: {
                        addPrayerPartner()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(newPartnerText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                            .font(.title3)
                    }
                    .disabled(newPartnerText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Quick Suggestions (from previous entries)
                if !suggestedPartners.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedPartners.prefix(5), id: \.self) { partner in
                                    Button(action: {
                                        if !prayerPartners.contains(partner) {
                                            prayerPartners.append(partner)
                                            hasUnsavedChanges = true
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.circle")
                                                .font(.caption2)
                                            Text(partner)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Link Journal Entry
            Button(action: { showingJournalEntryPicker = true }) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(.blue)
                    Text(linkedJournalEntryId == nil ? "Link Journal Entry" : "Journal Entry Linked")
                        .foregroundColor(linkedJournalEntryId == nil ? .secondary : .primary)
                    Spacer()
                    if linkedJournalEntryId != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Photo Attachment
            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.green)
                        Text(photoImage == nil ? "Add Photo" : "Photo Added")
                        Spacer()
                        if photoImage != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                if photoImage != nil {
                    Button(action: {
                        self.photoImage = nil
                        photoURL = nil
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var privacyCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple)
                Text("Private Prayer")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $isPrivate)
            }
            
            // Privacy Notice
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Notice")
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("All prayer requests are stored securely on your device and synced via Firebase. Private prayers are only visible to you.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func addPrayerPartner() {
        let trimmed = newPartnerText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !prayerPartners.contains(trimmed) else {
            // Partner already exists, clear the text field
            newPartnerText = ""
            return
        }
        
        // Add partner - use withAnimation for smooth UI update
        withAnimation {
            prayerPartners.append(trimmed)
            newPartnerText = ""
            hasUnsavedChanges = true
        }
    }
    
    private func loadSuggestedPartners() {
        // Get partners from recent prayer requests - run on main thread safely
        Task { @MainActor in
            do {
                let request = FetchDescriptor<PrayerRequest>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let requests = try modelContext.fetch(request)
                let allPartners = requests.flatMap { $0.prayerPartners }
                let partnerCounts = Dictionary(grouping: allPartners, by: { $0 })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                suggestedPartners = Array(partnerCounts.prefix(10).map { $0.key })
            } catch {
                // Silently fail - suggestions are optional
                print("Could not load suggested partners: \(error.localizedDescription)")
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !requestTags.contains(trimmed) {
            requestTags.append(trimmed)
            newTagText = ""
            hasUnsavedChanges = true
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileName = "\(UUID().uuidString).jpg"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                if let jpegData = image.jpegData(compressionQuality: 0.8) {
                    try? jpegData.write(to: fileURL)
                    photoURL = fileURL
                    photoImage = image
                    hasUnsavedChanges = true
                }
            }
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    private func startVoiceToText() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            showingErrorAlert = true
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.isTranscribing = true
                    self.startRecording()
                } else {
                    self.errorMessage = "Speech recognition permission denied."
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func startRecording() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.description = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    self.audioEngine?.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isTranscribing = false
                }
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingErrorAlert = true
            isTranscribing = false
        }
    }
    
    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if hasUnsavedChanges && !title.isEmpty && !description.isEmpty {
                saveDraft()
            }
        }
    }
    
    private func saveDraft() {
        let draft: [String: Any] = [
            "title": title,
            "description": description,
            "tags": requestTags,
            "category": selectedCategory,
            "priority": priority.rawValue,
            "date": requestDate,
            "isPrivate": isPrivate,
            "enableReminder": enableReminder,
            "reminderTime": reminderTime,
            "reminderFrequency": reminderFrequency.rawValue,
            "relatedBibleVerse": relatedBibleVerse,
            "prayerPartners": prayerPartners,
            "recurringPrayer": recurringPrayer.rawValue
        ]
        UserDefaults.standard.set(draft, forKey: "prayerRequestDraft")
        hasUnsavedChanges = false
    }
    
    private func saveRequestImmediately() async {
        guard !title.isEmpty && !description.isEmpty else { return }
        
        // Check if request already exists
        let request = FetchDescriptor<PrayerRequest>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        if let existingRequest = try? modelContext.fetch(request).first(where: { req in
            req.title == title && 
            req.details == description && 
            req.createdAt >= fiveMinutesAgo
        }) {
            existingRequest.isPrivate = isPrivate
            existingRequest.prayerPartners = prayerPartners
            existingRequest.enableReminder = enableReminder
            existingRequest.reminderTime = reminderTime
            existingRequest.reminderFrequency = reminderFrequency.rawValue
            existingRequest.updatedAt = Date()
        } else {
            var allTags = requestTags
            if !selectedCategory.isEmpty && !allTags.contains(selectedCategory) {
                allTags.insert(selectedCategory, at: 0)
            }
            
            let newRequest = PrayerRequest(
                title: title,
                details: description,
                tags: allTags,
                isPrivate: isPrivate
            )
            newRequest.date = requestDate
            newRequest.prayerPartners = prayerPartners
            newRequest.enableReminder = enableReminder
            newRequest.reminderTime = reminderTime
            newRequest.reminderFrequency = reminderFrequency.rawValue
            modelContext.insert(newRequest)
        }
        
        do {
            try modelContext.save()
            hasUnsavedChanges = false
        } catch {
            print("❌ Error auto-saving prayer request: \(error.localizedDescription)")
        }
    }
    
    private func loadRequestForEditing(_ request: PrayerRequest) {
        title = request.title
        description = request.details
        requestTags = request.tags
        isPrivate = request.isPrivate
        requestDate = request.date
        prayerPartners = request.prayerPartners
        enableReminder = request.enableReminder
        reminderTime = request.reminderTime
        reminderFrequency = ReminderFrequency(rawValue: request.reminderFrequency) ?? .daily
        
        // Extract category from tags if present
        if let firstTag = request.tags.first,
           categories.contains(where: { $0.name == firstTag }) {
            selectedCategory = firstTag
        }
    }
    
    private func saveRequest() {
        isSaving = true
        
        // Check if we're editing an existing request
        if let existingRequest = requestToEdit {
            // Update existing request
            var allTags = requestTags
            if !selectedCategory.isEmpty && !allTags.contains(selectedCategory) {
                allTags.insert(selectedCategory, at: 0)
            }
            
            existingRequest.title = title
            existingRequest.details = description
            existingRequest.tags = allTags
            existingRequest.isPrivate = isPrivate
            existingRequest.date = requestDate
            existingRequest.prayerPartners = prayerPartners
            existingRequest.enableReminder = enableReminder
            existingRequest.reminderTime = reminderTime
            existingRequest.reminderFrequency = reminderFrequency.rawValue
            existingRequest.updatedAt = Date()
            
            // Schedule reminder if enabled
            if enableReminder {
                scheduleReminder()
            }
            
            do {
                try modelContext.save()
                print("✅ Prayer request updated successfully: \(existingRequest.title)")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncPrayerRequest(existingRequest)
                    print("✅ [FIREBASE] Prayer request synced to Firebase")
                }
                
                isSaving = false
                showingSaveSuccess = true
            } catch {
                print("❌ Error updating prayer request: \(error.localizedDescription)")
                errorMessage = "Failed to update prayer request. Please try again.\n\n\(error.localizedDescription)"
                showingErrorAlert = true
                isSaving = false
            }
        } else {
            // Create new request
            var allTags = requestTags
            if !selectedCategory.isEmpty && !allTags.contains(selectedCategory) {
                allTags.insert(selectedCategory, at: 0)
            }
            
            let request = PrayerRequest(
                title: title,
                details: description,
                tags: allTags,
                isPrivate: isPrivate
            )
            request.date = requestDate
            request.prayerPartners = prayerPartners
            request.enableReminder = enableReminder
            request.reminderTime = reminderTime
            request.reminderFrequency = reminderFrequency.rawValue
            
            // Schedule reminder if enabled
            if enableReminder {
                scheduleReminder()
            }
            
            modelContext.insert(request)
            
            do {
                try modelContext.save()
                // Clear draft
                UserDefaults.standard.removeObject(forKey: "prayerRequestDraft")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncPrayerRequest(request)
                    print("✅ [FIREBASE] Prayer request synced to Firebase")
                }
                
                isSaving = false
                showingSaveSuccess = true
            } catch {
                print("❌ Error saving prayer request: \(error.localizedDescription)")
                errorMessage = "Failed to save prayer request. Please try again.\n\n\(error.localizedDescription)"
                showingErrorAlert = true
                modelContext.delete(request)
                isSaving = false
            }
        }
    }
    
    private func scheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Prayer Reminder"
                content.body = title
                content.sound = .default
                
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
                
                var dateComponents = DateComponents()
                dateComponents.hour = components.hour
                dateComponents.minute = components.minute
                
                if reminderFrequency == .daily {
                    dateComponents.weekday = nil
                } else if reminderFrequency == .weekly {
                    dateComponents.weekday = calendar.component(.weekday, from: Date())
                }
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: reminderFrequency != .custom)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
}

// MARK: - Supporting Views and Structures

struct PrayerTemplate: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    
    static func == (lhs: PrayerTemplate, rhs: PrayerTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

@available(iOS 17.0, *)
struct PrayerTemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTemplate: PrayerTemplate?
    
    let templates: [PrayerTemplate] = [
        PrayerTemplate(title: "Healing Prayer", description: "Lord, I pray for healing and restoration. Please bring comfort and strength during this time of need.", category: "Health"),
        PrayerTemplate(title: "Family Protection", description: "Heavenly Father, I pray for protection and blessing over my family. Keep us safe and draw us closer to You.", category: "Family"),
        PrayerTemplate(title: "Guidance at Work", description: "God, I need Your wisdom and guidance in my work. Help me to honor You in all that I do.", category: "Work"),
        PrayerTemplate(title: "Financial Provision", description: "Lord, I trust You for provision. Please meet our financial needs according to Your riches in glory.", category: "Financial"),
        PrayerTemplate(title: "Spiritual Growth", description: "Father, I desire to grow closer to You. Help me to deepen my faith and understanding of Your Word.", category: "Spiritual Growth")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    Button(action: {
                        selectedTemplate = template
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(template.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                            Text(template.category)
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Prayer Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct JournalEntryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedEntryId: UUID?
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) private var entries: [JournalEntry]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries.prefix(20)) { entry in
                    Button(action: {
                        selectedEntryId = entry.id
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(entry.content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Link Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct PrayerRequestDetailView: View {
    let request: PrayerRequest
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingAnswerSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    
    var shareText: String {
        var text = """
        Prayer Request: \(request.title)
        
        \(request.details)
        
        Status: \(request.status.rawValue)
        Date: \(request.date.formatted())
        Tags: \(request.tags.joined(separator: ", "))
        """
        if !request.prayerPartners.isEmpty {
            text += "\nPrayer Partners: \(request.prayerPartners.joined(separator: ", "))"
        }
        return text
    }
    
    var statusColor: Color {
        switch request.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .archived:
            return .gray
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(request.title)
                            .font(.title)
                            .font(.body.weight(.bold))
                        
                        Spacer()
                        
                        if request.isPrivate {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                        
                        if request.isAnswered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        Text(request.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(request.status.rawValue)
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.1))
                            .foregroundColor(statusColor)
                            .cornerRadius(12)
                    }
                }
                
                // Description
                Text(request.details)
                    .font(.body)
                    .lineSpacing(4)
                
                // Tags
                if !request.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(.primary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(request.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Prayer Partners
                if !request.prayerPartners.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("Prayer Partners")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(request.prayerPartners, id: \.self) { partner in
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.caption)
                                        Text(partner)
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                
                // Prayer Reminders
                if request.enableReminder {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.purple)
                            Text("Prayer Reminder")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Time:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(request.reminderTime, style: .time)
                                    .font(.subheadline)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                            }
                            HStack {
                                Text("Frequency:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(request.reminderFrequency)
                                    .font(.subheadline)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Answer Section
                if request.isAnswered {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Prayer Answered")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        if let answerDate = request.answerDate {
                            Text("Answered on \(answerDate, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let answerNotes = request.answerNotes, !answerNotes.isEmpty {
                            Text(answerNotes)
                                .font(.body)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                if request.status == .active {
                    Button(action: { showingAnswerSheet = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark as Answered")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Prayer Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    if request.status == .active {
                        Button("Mark as Answered") { showingAnswerSheet = true }
                        Button("Archive") { archiveRequest() }
                    } else if request.status == .answered {
                        Button("Mark as Active") { activateRequest() }
                        Button("Archive") { archiveRequest() }
                    } else if request.status == .archived {
                        Button("Mark as Active") { activateRequest() }
                    }
                    Button("Edit") { showingEditSheet = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: [shareText])
        }
        .sheet(isPresented: $showingEditSheet) {
            NewPrayerRequestView(request: request)
        }
        .sheet(isPresented: $showingAnswerSheet) {
            AnswerPrayerRequestView(request: request)
        }
        .alert("Delete Prayer Request", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                let requestToDelete = request
                modelContext.delete(request)
                do {
                    try modelContext.save()
                    
                    // Sync deletion to Firebase
                    Task {
                        await FirebaseSyncService.shared.deletePrayerRequest(requestToDelete)
                        print("✅ [FIREBASE] Prayer request deletion synced to Firebase")
                    }
                } catch {
                    print("❌ Error deleting prayer request: \(error.localizedDescription)")
                    ErrorHandler.shared.handle(.deleteFailed)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this prayer request? This action cannot be undone.")
        }
    }
    
    private func archiveRequest() {
        request.status = .archived
        request.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncPrayerRequest(request)
                print("✅ [FIREBASE] Prayer request status change synced to Firebase")
            }
        } catch {
            print("❌ Error archiving prayer request: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
    
    private func activateRequest() {
        request.status = .active
        request.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncPrayerRequest(request)
                print("✅ [FIREBASE] Prayer request status change synced to Firebase")
            }
        } catch {
            print("❌ Error activating prayer request: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
}

@available(iOS 17.0, *)
struct AnswerPrayerRequestView: View {
    let request: PrayerRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var answerNotes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How was your prayer answered?")) {
                    TextEditor(text: $answerNotes)
                        .frame(height: 120)
                }
                
                Section {
                    Text("Marking this prayer as answered will help you track God's faithfulness in your life.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Prayer Answered")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAnswer() }
                }
            }
        }
    }
    
    private func saveAnswer() {
        request.status = .answered
        request.isAnswered = true
        request.answerDate = Date()
        request.answerNotes = answerNotes.isEmpty ? nil : answerNotes
        request.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncPrayerRequest(request)
                print("✅ [FIREBASE] Prayer request answer synced to Firebase")
            }
            
            dismiss()
        } catch {
            print("❌ Error saving prayer answer: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
}

@available(iOS 17.0, *)
struct EditPrayerRequestView: View {
    let request: PrayerRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var description: String
    @State private var tags: String
    @State private var isPrivate: Bool
    @State private var selectedCategory: String
    
    init(request: PrayerRequest) {
        self.request = request
        _title = State(initialValue: request.title)
        _description = State(initialValue: request.details)
        _tags = State(initialValue: request.tags.joined(separator: ", "))
        _isPrivate = State(initialValue: request.isPrivate)
        _selectedCategory = State(initialValue: request.tags.first ?? "")
    }
    
    let categories = ["", "Health", "Family", "Work", "Relationships", "Spiritual Growth", "Financial", "Emotional", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Prayer Title", text: $title)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("No category").tag("")
                        ForEach(categories.dropFirst(), id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                
                Section {
                    Toggle("Private Prayer", isOn: $isPrivate)
                }
            }
            .navigationTitle("Edit Prayer Request")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        var allTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !selectedCategory.isEmpty {
            allTags.insert(selectedCategory, at: 0)
        }
        
        request.title = title
        request.details = description
        request.tags = allTags
        request.isPrivate = isPrivate
        request.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Error saving prayer request changes: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
} 