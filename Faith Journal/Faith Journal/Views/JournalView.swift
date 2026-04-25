import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import PencilKit
import CoreLocation
import MapKit
import Speech

@available(iOS 17.0, *)
struct JournalView: View {
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) var entries: [JournalEntry]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false
    @State private var searchText = ""
    @State private var selectedFilter: JournalFilter = .all
    @State private var showingFilterSheet = false
    
    var filteredEntries: [JournalEntry] {
        var filtered = entries
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = applySearchFilter(to: filtered)
        }
        
        // Apply category filter
        filtered = applyCategoryFilter(to: filtered)
        
        return filtered
    }
    
    private func applySearchFilter(to entries: [JournalEntry]) -> [JournalEntry] {
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.content.localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (entry.audioTranscript?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private func applyCategoryFilter(to entries: [JournalEntry]) -> [JournalEntry] {
        switch selectedFilter {
        case .all:
            return entries
        case .private:
            return entries.filter { $0.isPrivate }
        case .public:
            return entries.filter { !$0.isPrivate }
        case .withMedia:
            return entries.filter { !$0.photoURLs.isEmpty || $0.audioURL != nil || $0.drawingData != nil }
        case .mood(let mood):
            return entries.filter { $0.mood == mood }
        }
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    JournalSearchAndFilterBar(
                        searchText: $searchText,
                        selectedFilter: $selectedFilter
                    )
                    .padding()
                    .background(Color(.systemBackground))
                    
                    if filteredEntries.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Journal Entries")
                                .font(.title2)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Start your faith journey by creating your first journal entry")
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: { showingNewEntry = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create First Entry")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        JournalEntriesList(
                            entries: filteredEntries,
                            deleteEntry: deleteEntry
                        )
                    }
                }
                .navigationTitle("Journal")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingNewEntry = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingNewEntry) {
                    NewJournalEntryView()
                }
            }
            .onAppear {
                // Create sample data if no entries exist
                if entries.isEmpty {
                    createSampleEntries()
                }
            }
            .onChange(of: showingNewEntry) { oldValue, newValue in
                // When the sheet closes, ensure the view refreshes
                // @Query should automatically update, but this ensures it
                if oldValue == true && newValue == false {
                    // Sheet was dismissed - entries should already be updated via @Query
                    // This is just a safety check
                    print("✅ Journal entry sheet dismissed. Current entries count: \(entries.count)")
                }
            }
        } else {
            Text("Journal is only available on iOS 17+")
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        var entriesToDelete: [JournalEntry] = []
        for index in offsets {
            guard index < filteredEntries.count else { continue }
            let entry = filteredEntries[index]
            entriesToDelete.append(entry)
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
            
            // Sync deletions to Firebase for cross-device sync
            Task {
                for entry in entriesToDelete {
                    await FirebaseSyncService.shared.deleteJournalEntry(entry)
                }
                print("✅ [FIREBASE] Bulk deletion synced to Firebase (\(entriesToDelete.count) entries)")
            }
        } catch {
            print("❌ Error deleting journal entry: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.deleteFailed)
        }
    }
    
    private func createSampleEntries() {
        let sampleEntries = [
            JournalEntry(
                title: "God's Faithfulness Today",
                content: "Today I experienced God's faithfulness in a beautiful way. Despite the challenges I faced, I felt His presence guiding me through each moment. I'm reminded that He is always with me, even in the smallest details of life.",
                tags: ["faithfulness", "gratitude", "daily-blessings"],
                mood: "Grateful",
                isPrivate: false
            ),
            JournalEntry(
                title: "Prayer Answered",
                content: "After weeks of praying for guidance about my career decision, I finally received clarity today. God opened a door I never expected, and I can see His hand in the timing of everything. This reminds me that His timing is always perfect.",
                tags: ["prayer", "guidance", "answered-prayers"],
                mood: "Hopeful",
                isPrivate: true
            ),
            JournalEntry(
                title: "Learning to Trust",
                content: "I'm learning that trust in God isn't about having all the answers, but about believing that He has them. Today's uncertainty taught me to lean on Him more deeply and to find peace in the unknown.",
                tags: ["trust", "faith", "growth"],
                mood: "Reflective",
                isPrivate: false
            )
        ]
        
        for entry in sampleEntries {
            modelContext.insert(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error creating sample entries: \(error.localizedDescription)")
            // Don't show error to user for sample data, just log it
        }
    }
}

@available(iOS 17.0, *)
struct JournalEntryRow: View {
    let entry: JournalEntry
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primary)
                
                Spacer()
                
                if entry.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.primary)
                        .font(.caption)
                }
                
                if !entry.photoURLs.isEmpty || entry.audioURL != nil || entry.drawingData != nil {
                    Image(systemName: "paperclip")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            Text(entry.content)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.primary)
            
            HStack {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                if let mood = entry.mood {
                    Text("• \(mood)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                        HStack(spacing: 4) {
                            ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

enum JournalFilter: Equatable {
    case all, `private`, `public`, withMedia, mood(String)
}

// MARK: - Mood Data Structure
struct MoodOption: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
}

@available(iOS 17.0, *)
struct NewJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // Optional entry for editing mode
    let entryToEdit: JournalEntry?
    
    // Core fields
    @State private var title = ""
    @State private var content = ""
    @State private var entryTags: [String] = []
    @State private var newTagText = ""
    @State private var suggestedTags: [String] = []
    @State private var isPrivate = false
    @State private var selectedMood: String = ""
    @State private var moodIntensity: Double = 5.0
    @State private var entryDate: Date = Date()
    @State private var dateSelectionMode: DateSelectionMode = .today
    
    // Media
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [URL] = []
    @State private var photoImages: [UIImage] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioURL: URL?
    @State private var audioTranscript: String?
    @State private var isTranscribing = false
    @State private var isPaused = false
    @State private var pausedDuration: TimeInterval = 0
    @State private var pauseStartTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordingStartTime: Date?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingDrawingSheet = false
    @State private var drawingData: Data?
    @State private var drawingImage: UIImage?
    
    // Additional features
    @State private var location: String = ""
    @State private var weather: String = ""
    @State private var bibleVerse: String = ""
    @State private var linkedPrayerRequestId: UUID?
    
    // Initialize for new entry or edit mode
    init(entry: JournalEntry? = nil) {
        self.entryToEdit = entry
    }
    
    // UI State
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingPromptPicker = false
    @State private var selectedPrompt: JournalPrompt?
    @State private var isSaving = false
    @State private var showingLocationPicker = false
    @State private var showingBibleVersePicker = false
    @State private var showingSaveSuccess = false
    @State private var showPrivateToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "lock.fill"
    
    // Services
    // Use regular property for singleton, not @StateObject
    private let promptManager = PromptManager.shared
    @StateObject private var locationManager = LocationManager()
    
    // Auto-save
    @State private var autoSaveTimer: Timer?
    @State private var hasUnsavedChanges = false
    
    // Mood options with emojis and colors
    let moodOptions: [MoodOption] = [
        MoodOption(name: "Happy", emoji: "😊", color: .yellow),
        MoodOption(name: "Grateful", emoji: "🙏", color: .green),
        MoodOption(name: "Peaceful", emoji: "☮️", color: .blue),
        MoodOption(name: "Reflective", emoji: "🤔", color: .purple),
        MoodOption(name: "Challenged", emoji: "💪", color: .orange),
        MoodOption(name: "Hopeful", emoji: "✨", color: .pink),
        MoodOption(name: "Anxious", emoji: "😰", color: .red),
        MoodOption(name: "Joyful", emoji: "😄", color: .yellow)
    ]
    
    enum DateSelectionMode {
        case today, yesterday, custom
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 20) {
            // Quick Actions (Prompts & Date)
            quickActionsSection
            
            // Title Card
            titleCard
            
            // Content Card with Voice-to-Text
            contentCard
            
            // Mood Card with Visual Picker
            moodCard
            
            // Tags Card with Chips
            tagsCard
            
            // Media Card with Previews
            mediaCard
            
            // Additional Info Card
            additionalInfoCard
            
            // Privacy Toggle
            privacyCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Gradient Header
                        gradientHeader
                        
                        // Main Content
                        mainContentSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(entryToEdit == nil ? "New Entry" : "Edit Entry")
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
                    Button(action: saveEntry) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(entryToEdit == nil ? "Save" : "Update")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
        }
        .sheet(isPresented: $showingDrawingSheet) {
            DrawingView(drawingData: $drawingData)
        }
        .sheet(isPresented: $showingPromptPicker) {
            PromptPickerView(selectedPrompt: $selectedPrompt, selectedCategory: .constant(nil))
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: $location)
        }
        .sheet(isPresented: $showingBibleVersePicker) {
            BibleVersePickerView(selectedVerse: $bibleVerse)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.isEmpty ? "An unknown error occurred" : errorMessage)
        }
        .alert(entryToEdit == nil ? "Entry Saved" : "Entry Updated", isPresented: $showingSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(entryToEdit == nil ? "Your journal entry has been saved successfully!" : "Your journal entry has been updated successfully!")
        }
        .onAppear {
            setupAudioRecorder()
            setupAutoSave()
            loadLocationAndWeather()
            
            // Load suggested tags once when view appears
            loadSuggestedTags()
            
            // If editing, load entry data
            if let entry = entryToEdit {
                loadEntryForEditing(entry)
            }
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
            // Stop recording if still active
            if isRecording {
                stopRecording()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            JournalActivityView(activityItems: shareItems)
        }
        .onChange(of: selectedPhotos) { _, newValue in
            loadPhotos(from: newValue)
        }
        .onChange(of: drawingData) { _, newValue in
            if let data = newValue {
                drawingImage = UIImage(data: data)
            }
        }
        .onChange(of: selectedPrompt) { _, newValue in
            if let prompt = newValue {
                content = prompt.promptText + "\n\n"
            }
        }
        .onChange(of: isPrivate) { oldValue, newValue in
            // Show toast when privacy status changes
            if newValue != oldValue {
                if newValue {
                    // Made private
                    toastMessage = "Journal entry is now private"
                    toastIcon = "lock.fill"
                } else {
                    // Made public
                    toastMessage = "Journal entry is now public"
                    toastIcon = "lock.open.fill"
                }
                showPrivateToast = true
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showPrivateToast = false
                }
            }
            
            // Auto-save entry when private status changes (if entry has minimum required fields)
            if !title.isEmpty && !content.isEmpty {
                hasUnsavedChanges = true
                // Save immediately to register the private status
                Task {
                    await saveEntryImmediately()
                }
            } else {
                // Update draft even if not ready to save
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
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("New Journal Entry")
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
                // Journal Prompt Button
                Button(action: { showingPromptPicker = true }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Use Prompt")
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
                        entryDate = Date()
                    }) {
                        Label("Today", systemImage: "calendar")
                    }
                    Button(action: {
                        dateSelectionMode = .yesterday
                        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                            entryDate = yesterday
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
                DatePicker("Entry Date", selection: $entryDate, displayedComponents: .date)
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
                Text("Title")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            TextField("Give your entry a title...", text: $title)
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
    
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("Content")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // Note: Users can use iOS built-in dictation via the keyboard microphone button
            }
            
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("What's on your heart today?")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $content)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Character count
            HStack {
                Spacer()
                Text("\(content.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "face.smiling.fill")
                    .foregroundColor(.purple)
                Text("How are you feeling?")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            #if os(macOS)
            // Dropdown on macOS — horizontal scroll unreliable
            Picker("Mood", selection: $selectedMood) {
                Text("None").tag("")
                ForEach(moodOptions) { mood in
                    Text("\(mood.emoji) \(mood.name)")
                        .tag(mood.name)
                }
            }
            .pickerStyle(.menu)
            #else
            // Visual Mood Picker on iOS
            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                HStack(spacing: 12) {
                    ForEach(moodOptions) { mood in
                        Button(action: {
                            selectedMood = mood.name
                        }) {
                            VStack(spacing: 8) {
                                Text(mood.emoji)
                                    .font(.system(size: 40))
                                Text(mood.name)
                                    .font(.caption)
                                    .font(.body.weight(.medium))
                            }
                            .foregroundColor(selectedMood == mood.name ? .white : .primary)
                            .frame(width: 80, height: 100)
                            .background(selectedMood == mood.name ? mood.color : Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedMood == mood.name ? mood.color : Color.clear, lineWidth: 3)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            #endif
            
            // Mood Intensity Slider (if mood selected)
            if !selectedMood.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Intensity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(moodIntensity))")
                            .font(.subheadline)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.purple)
                    }
                    Slider(value: $moodIntensity, in: 1...10, step: 1)
                        .tint(.purple)
                }
                .padding(.top, 8)
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
            if !entryTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 8) {
                        ForEach(entryTags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.subheadline)
                                Button(action: {
                                    entryTags.removeAll { $0 == tag }
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
            
            // Suggested Tags (from previous entries)
            if !suggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    #if os(macOS)
                    // Dropdown on macOS — horizontal scroll unreliable
                    Menu {
                        ForEach(suggestedTags.prefix(10), id: \.self) { tag in
                            Button(tag) {
                                if !entryTags.contains(tag) {
                                    entryTags.append(tag)
                                }
                            }
                        }
                    } label: {
                        Label("Add suggested tag", systemImage: "tag.badge.plus")
                    }
                    #else
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                        HStack(spacing: 8) {
                            ForEach(suggestedTags.prefix(5), id: \.self) { tag in
                                Button(action: {
                                    if !entryTags.contains(tag) {
                                        entryTags.append(tag)
                                    }
                                }) {
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 40)
                    .fixedSize(horizontal: false, vertical: true)
                    #endif
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.purple)
                Text("Media")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if !photoURLs.isEmpty || audioURL != nil || drawingData != nil {
                    Text("\(mediaCount) attached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Photo Previews
            if !photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 12) {
                        ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(12)
                                    .clipped()
                                
                                Button(action: {
                                    photoImages.remove(at: index)
                                    photoURLs.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
            
            // Drawing Preview
            if let drawingImage = drawingImage {
                HStack {
                    Image(uiImage: drawingImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .cornerRadius(8)
                    
                    Button(action: {
                        drawingData = nil
                        self.drawingImage = nil
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Recording Indicator (while recording)
            if isRecording {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(isPaused ? "Paused" : "Recording...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isPaused ? .orange : .red)
                        Text(formatDuration(recordingDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Pause/Resume button
                    Button(action: {
                        if isPaused {
                            resumeRecording()
                        } else {
                            pauseRecording()
                        }
                    }) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(isPaused ? .green : .orange)
                    }
                    
                    // Pulsing red dot indicator (only when not paused)
                    if !isPaused {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Audio Preview (after recording is saved) - with playback controls
            if audioURL != nil && !isRecording {
                VStack(spacing: 12) {
                    AudioPlayerView(audioURL: audioURL!)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 8) {
                                // Share/Export button
                                Button(action: {
                                    shareAudioFile()
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.blue)
                                        .padding(8)
                                }
                                
                                // Delete button
                                Button(action: {
                                    self.audioURL = nil
                                    self.audioTranscript = nil
                                    recordingDuration = 0
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .padding(8)
                                }
                            }
                        }
                    
                    // Transcription status
                    if isTranscribing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Transcribing audio...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Display transcript if available
                    if let transcript = audioTranscript, !transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Transcript")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    // Copy transcript to content
                                    if content.isEmpty {
                                        content = transcript
                                    } else {
                                        content += "\n\n📝 \(transcript)"
                                    }
                                    hasUnsavedChanges = true
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text(transcript)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                .onAppear {
                    // Update duration if available from file
                    if let player = try? AVAudioPlayer(contentsOf: audioURL!) {
                        recordingDuration = player.duration
                    }
                }
            }
            
            // Media Action Buttons
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Photos")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    toggleRecording()
                }) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        Text(isRecording ? "Stop" : "Record")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: { showingDrawingSheet = true }) {
                    HStack {
                        Image(systemName: "pencil.tip")
                        Text("Draw")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var additionalInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.purple)
                Text("Additional Info")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Location
            Button(action: { showingLocationPicker = true }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(location.isEmpty ? "Add Location" : location)
                        .foregroundColor(location.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !location.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Weather (auto-filled if location available)
            if !weather.isEmpty {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(.orange)
                    Text(weather)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Bible Verse
            Button(action: { showingBibleVersePicker = true }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.purple)
                    Text(bibleVerse.isEmpty ? "Add Bible Verse" : bibleVerse)
                        .foregroundColor(bibleVerse.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !bibleVerse.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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
    
    private var privacyCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple)
                Text("Private Entry")
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
                    Text("All journal entries are stored securely on your device and synced via Firebase. Private entries are only visible to you and are not shared with anyone.")
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
    
    private var mediaCount: Int {
        var count = 0
        if !photoURLs.isEmpty { count += photoURLs.count }
        if audioURL != nil { count += 1 }
        if drawingData != nil { count += 1 }
        return count
    }
    
    // MARK: - Helper Methods
    
    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !entryTags.contains(trimmed) {
            entryTags.append(trimmed)
            newTagText = ""
            hasUnsavedChanges = true
        }
    }
    
    /// Load suggested tags once and cache them to prevent shuffling
    private func loadSuggestedTags() {
        // Get tags from recent entries
        let request = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let entries = try? modelContext.fetch(request) {
            let allTags = entries.flatMap { $0.tags }
            let tagCounts = Dictionary(grouping: allTags, by: { $0 })
                .mapValues { $0.count }
                // Stable sort: first by count (descending), then by name (ascending) for consistent ordering
                .sorted { first, second in
                    if first.value != second.value {
                        return first.value > second.value
                    }
                    return first.key < second.key
                }
            suggestedTags = Array(tagCounts.prefix(10).map { $0.key })
        } else {
            suggestedTags = []
        }
    }
    
    /// Legacy function kept for compatibility (now uses cached suggestions)
    private func getSuggestedTags() -> [String]? {
        return suggestedTags.isEmpty ? nil : suggestedTags
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            photoURLs = []
            photoImages = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    if let jpegData = image.jpegData(compressionQuality: 0.8) {
                        try? jpegData.write(to: fileURL)
                        photoURLs.append(fileURL)
                        photoImages.append(image)
                    }
                }
            }
            hasUnsavedChanges = true
        }
    }
    
    private func setupAudioRecorder() {
        // Audio session will be configured when recording starts
        // This function kept for compatibility but does minimal setup
    }
    
    private func startRecordingWithEngine() {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        errorMessage = "Audio recording requires a real device. The iOS Simulator doesn't have a microphone. Please test on a physical iPhone or iPad."
        showingErrorAlert = true
        print("⚠️ Recording not available in iOS Simulator - requires real device")
        return
        #else
        // Verify permission is granted (iOS 17+ API)
        guard AVAudioApplication.shared.recordPermission == .granted else {
            errorMessage = "Microphone permission is required. Please grant permission and try again."
            showingErrorAlert = true
            print("❌ Permission not granted")
            return
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ Audio session activated for recording")
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            showingErrorAlert = true
            print("❌ Audio session setup failed: \(error)")
            return
        }
        
        // Create file URL
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Failed to access documents directory."
            showingErrorAlert = true
            return
        }
        
        let audioFileName = "\(UUID().uuidString).m4a"
        let audioFileURL = documentsPath.appendingPathComponent(audioFileName)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: audioFileURL.path) {
            try? FileManager.default.removeItem(at: audioFileURL)
        }
        
        // Use iOS built-in AVAudioRecorder with standard settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create AVAudioRecorder (iOS built-in recording API)
            let recorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            recorder.delegate = nil // We'll handle completion manually
            recorder.isMeteringEnabled = false
            
            // Prepare and start recording
            guard recorder.prepareToRecord() else {
                errorMessage = "Failed to prepare audio recorder. Please try again."
                showingErrorAlert = true
                print("❌ Failed to prepare recorder")
                try? audioSession.setActive(false)
                return
            }
            
            guard recorder.record() else {
                errorMessage = "Failed to start recording. Please try again."
                showingErrorAlert = true
                print("❌ Failed to start recording")
                try? audioSession.setActive(false)
                return
            }
            
            // Store recorder and URL
            audioRecorder = recorder
            audioURL = audioFileURL
            
            // Update state
            let startTime = Date()
            recordingStartTime = startTime
            isRecording = true
            isPaused = false
            recordingDuration = 0
            pausedDuration = 0
            pauseStartTime = nil
            
            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    if !self.isPaused, let start = self.recordingStartTime {
                        self.recordingDuration = self.pausedDuration + Date().timeIntervalSince(start)
                    }
                }
            }
            
            print("✅ Recording started successfully with AVAudioRecorder (iOS built-in)")
            print("✅ File: \(audioFileURL.lastPathComponent)")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingErrorAlert = true
            print("❌ Failed to start recording: \(error)")
            audioRecorder = nil
            audioURL = nil
            try? audioSession.setActive(false)
        }
        #endif
    }
    
    private func toggleRecording() {
        if isRecording {
            // Stop recording
            stopRecording()
        } else {
            // Check microphone permission and start recording
            let permissionStatus = AVAudioApplication.shared.recordPermission
            
            print("📱 Microphone permission status: \(permissionStatus)")
            
            switch permissionStatus {
            case .granted:
                print("✅ Permission already granted, starting recording...")
                startRecordingWithEngine()
                
            case .denied:
                errorMessage = "Microphone permission is denied. Please enable it in Settings > Faith Journal > Microphone."
                showingErrorAlert = true
                print("❌ Microphone permission denied")
                
            case .undetermined:
                print("📝 Requesting microphone permission...")
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("✅ Microphone permission granted, starting recording...")
                            self.startRecordingWithEngine()
                        } else {
                            print("❌ Microphone permission denied by user")
                            self.errorMessage = "Microphone permission is required to record audio. Please enable it in Settings."
                            self.showingErrorAlert = true
                        }
                    }
                }
                
            @unknown default:
                errorMessage = "Unable to check microphone permission. Please try again."
                showingErrorAlert = true
                print("⚠️ Unknown microphone permission status")
            }
        }
        hasUnsavedChanges = true
    }
    
    private func pauseRecording() {
        guard isRecording && !isPaused, let recorder = audioRecorder else { return }
        
        // Pause recording using AVAudioRecorder's pause method
        recorder.pause()
        
        // Stop timer and calculate paused duration
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let startTime = recordingStartTime {
            pausedDuration += Date().timeIntervalSince(startTime)
        }
        pauseStartTime = Date()
        
        isPaused = true
        print("⏸️ Recording paused")
    }
    
    private func resumeRecording() {
        guard isRecording && isPaused, let recorder = audioRecorder else { return }
        
        // Resume recording using AVAudioRecorder's record method
        guard recorder.record() else {
            errorMessage = "Failed to resume recording. Please try again."
            showingErrorAlert = true
            print("❌ Failed to resume recording")
            return
        }
        
        // Update start time to account for pause duration
        recordingStartTime = Date()
        
        // Restart timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                if let start = self.recordingStartTime {
                    self.recordingDuration = self.pausedDuration + Date().timeIntervalSince(start)
                }
            }
        }
        
        isPaused = false
        print("▶️ Recording resumed")
    }
    
    private func stopRecording() {
        // Stop recording timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Stop AVAudioRecorder (iOS built-in)
        if let recorder = audioRecorder {
            recorder.stop()
            audioRecorder = nil
        }
        
        // Deactivate audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
        
        // Calculate final duration (accounting for pauses)
        if let startTime = recordingStartTime {
            if isPaused {
                // If paused, use the paused duration
                recordingDuration = pausedDuration
            } else {
                // If not paused, add current time to paused duration
                recordingDuration = pausedDuration + Date().timeIntervalSince(startTime)
            }
        }
        
        isRecording = false
        isPaused = false
        recordingStartTime = nil
        pauseStartTime = nil
        pausedDuration = 0
        
        // Only keep audioURL if recording duration > 0
        if recordingDuration <= 0 {
            print("⚠️ Recording duration is 0, removing audio file")
            if let url = audioURL {
                try? FileManager.default.removeItem(at: url)
            }
            audioURL = nil
        } else {
            print("✅ Audio recording saved: \(audioURL?.lastPathComponent ?? "unknown")")
            print("✅ Duration: \(recordingDuration) seconds")
            
            // Start automatic transcription
            if let url = audioURL {
                Task {
                    await transcribeAudio(url: url)
                }
            }
        }
    }
    
    // MARK: - Export & Share
    
    private func shareAudioFile() {
        guard let audioURL = audioURL else { return }
        
        // Copy file to temporary directory for sharing
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Journal_Audio_\(Date().timeIntervalSince1970).\(audioURL.pathExtension)"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // Copy file to temp directory
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: audioURL, to: tempURL)
            
            shareItems = [tempURL]
            showingShareSheet = true
        } catch {
            print("❌ Failed to prepare audio file for sharing: \(error.localizedDescription)")
            errorMessage = "Failed to prepare audio file for sharing."
            showingErrorAlert = true
        }
    }
    
    // MARK: - Speech Recognition / Transcription
    
    private func transcribeAudio(url: URL) async {
        await MainActor.run {
            isTranscribing = true
        }
        
        // Check speech recognition availability
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        if authStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume()
                }
            }
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("⚠️ Speech recognition not authorized")
            await MainActor.run {
                isTranscribing = false
            }
            return
        }
        
        // Create speech recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
              recognizer.isAvailable else {
            print("⚠️ Speech recognizer not available for current locale")
            await MainActor.run {
                isTranscribing = false
            }
            return
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation // Optimize for dictation/journaling
        
        // Perform recognition using helper class
        let helper = SpeechRecognitionHelper()
        let transcription = await helper.transcribe(request: request, recognizer: recognizer)
        
        await MainActor.run {
            if let transcription = transcription, !transcription.formattedString.isEmpty {
                audioTranscript = transcription.formattedString
                print("✅ Transcription completed: \(transcription.formattedString.prefix(50))...")
                
                // Optionally append transcript to content if empty
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    content = transcription.formattedString
                }
                hasUnsavedChanges = true
            } else {
                print("⚠️ Transcription returned empty result")
            }
            isTranscribing = false
        }
    }
    
    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if hasUnsavedChanges && !title.isEmpty && !content.isEmpty {
                saveDraft()
            }
        }
    }
    
    private func saveDraft() {
        // Auto-save to UserDefaults as draft
        let draft: [String: Any] = [
            "title": title,
            "content": content,
            "tags": entryTags,
            "mood": selectedMood,
            "date": entryDate,
            "isPrivate": isPrivate,
            "location": location,
            "bibleVerse": bibleVerse
        ]
        UserDefaults.standard.set(draft, forKey: "journalEntryDraft")
        hasUnsavedChanges = false
    }
    
    private func loadLocationAndWeather() {
        locationManager.requestLocation { location in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first {
                    self.location = [
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                }
            }
            // Fetch real weather data using WeatherService
            WeatherService.shared.fetchWeather(for: location) { result in
                switch result {
                case .success(let weatherString):
                    self.weather = weatherString
                case .failure:
                    // Fallback to empty string if weather fetch fails
                    self.weather = ""
                }
            }
        }
    }
    
    private func saveEntryImmediately() async {
        // Silent save without showing success alert or dismissing
        guard !title.isEmpty && !content.isEmpty else { return }
        
        // Check if entry already exists (was previously saved)
        let request = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        // Find entry with matching title and content (within last 5 minutes to avoid matching old entries)
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        if let existingEntry = try? modelContext.fetch(request).first(where: { entry in
            entry.title == title && 
            entry.content == content && 
            entry.createdAt >= fiveMinutesAgo
        }) {
            // Update existing entry
            existingEntry.isPrivate = isPrivate
            existingEntry.audioTranscript = audioTranscript
            existingEntry.updatedAt = Date()
            
            do {
                try modelContext.save()
                hasUnsavedChanges = false
                print("✅ [STORAGE] Journal entry updated successfully")
                print("✅ [STORAGE] Entry ID: \(existingEntry.id)")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncJournalEntry(existingEntry)
                }
            } catch {
                print("❌ Error updating journal entry: \(error.localizedDescription)")
            }
        } else {
            // Create new entry
            let entry = JournalEntry(
                title: title,
                content: content,
                tags: entryTags,
                mood: selectedMood.isEmpty ? nil : selectedMood,
                location: location.isEmpty ? nil : location,
                isPrivate: isPrivate
            )
            entry.date = entryDate
            entry.photoURLs = photoURLs
            entry.audioURL = audioURL
            entry.audioTranscript = audioTranscript
            entry.drawingData = drawingData
            
            // Add Bible verse to content if provided
            if !bibleVerse.isEmpty {
                entry.content = "📖 \(bibleVerse)\n\n\(content)"
            }
            
            modelContext.insert(entry)
            
            do {
                try modelContext.save()
                hasUnsavedChanges = false
                print("✅ [STORAGE] Journal entry saved successfully")
                print("✅ [STORAGE] Entry ID: \(entry.id)")
                print("✅ [STORAGE] Entry Title: \(entry.title)")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncJournalEntry(entry)
                    print("✅ [FIREBASE] Entry synced to Firebase - will appear on other devices")
                }
            } catch {
                print("❌ Error auto-saving journal entry: \(error.localizedDescription)")
                // Don't show error alert for auto-save, just log it
            }
        }
    }
    
    private func loadEntryForEditing(_ entry: JournalEntry) {
        title = entry.title
        content = entry.content
        entryTags = entry.tags
        isPrivate = entry.isPrivate
        selectedMood = entry.mood ?? ""
        entryDate = entry.date
        photoURLs = entry.photoURLs
        audioURL = entry.audioURL
        audioTranscript = entry.audioTranscript
        drawingData = entry.drawingData
        location = entry.location ?? ""
        
        // Extract Bible verse from content if present
        if content.hasPrefix("📖") {
            let components = content.components(separatedBy: "\n\n")
            if components.count > 1 {
                bibleVerse = String(components[0].dropFirst(2)) // Remove "📖 "
                content = components.dropFirst().joined(separator: "\n\n")
            }
        }
        
        // Load photo images from URLs
        photoImages = []
        for url in photoURLs {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                photoImages.append(image)
            }
        }
        
        // Load drawing image if available
        if let data = drawingData {
            drawingImage = UIImage(data: data)
        }
    }
    
    private func saveEntry() {
        isSaving = true
        
        // Check if we're editing an existing entry
        if let existingEntry = entryToEdit {
            // Update existing entry
            existingEntry.title = title
            existingEntry.content = content
            existingEntry.tags = entryTags
            existingEntry.mood = selectedMood.isEmpty ? nil : selectedMood
            existingEntry.location = location.isEmpty ? nil : location
            existingEntry.isPrivate = isPrivate
            existingEntry.date = entryDate
            existingEntry.photoURLs = photoURLs
            existingEntry.audioURL = audioURL
            existingEntry.audioTranscript = audioTranscript
            existingEntry.drawingData = drawingData
            existingEntry.updatedAt = Date()
            
            // Add Bible verse to content if provided
            if !bibleVerse.isEmpty {
                existingEntry.content = "📖 \(bibleVerse)\n\n\(content)"
            }
            
            do {
                try modelContext.save()
                print("✅ [STORAGE] Journal entry saved locally: \(existingEntry.title)")
                print("✅ [STORAGE] Entry ID: \(existingEntry.id)")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncJournalEntry(existingEntry)
                    print("✅ [FIREBASE] Entry synced to Firebase - will appear on other devices")
                }
                
                isSaving = false
                showingSaveSuccess = true
            } catch {
                print("❌ Error updating journal entry: \(error.localizedDescription)")
                errorMessage = "Failed to update journal entry. Please try again.\n\n\(error.localizedDescription)"
                showingErrorAlert = true
                isSaving = false
            }
        } else {
            // Create new entry
            let entry = JournalEntry(
                title: title,
                content: content,
                tags: entryTags,
                mood: selectedMood.isEmpty ? nil : selectedMood,
                location: location.isEmpty ? nil : location,
                isPrivate: isPrivate
            )
            entry.date = entryDate
            entry.photoURLs = photoURLs
            entry.audioURL = audioURL
            entry.audioTranscript = audioTranscript
            entry.drawingData = drawingData
            
            // Add Bible verse to content if provided
            if !bibleVerse.isEmpty {
                entry.content = "📖 \(bibleVerse)\n\n\(content)"
            }
            
            modelContext.insert(entry)
            
            do {
                try modelContext.save()
                print("✅ [STORAGE] Journal entry saved locally: \(entry.title)")
                print("✅ [STORAGE] Entry ID: \(entry.id)")
                print("✅ [STORAGE] Entry date: \(entry.date)")
                print("✅ [STORAGE] Entry isPrivate: \(entry.isPrivate)")
                
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncJournalEntry(entry)
                    print("✅ [FIREBASE] Entry synced to Firebase - will appear on other devices")
                }
                
                // Clear draft
                UserDefaults.standard.removeObject(forKey: "journalEntryDraft")
                isSaving = false
                showingSaveSuccess = true
            } catch {
                print("❌ Error saving journal entry: \(error.localizedDescription)")
                errorMessage = "Failed to save journal entry. Please try again.\n\n\(error.localizedDescription)"
                showingErrorAlert = true
                modelContext.delete(entry)
                isSaving = false
            }
        }
    }
}

// MARK: - Speech Recognition Helper

class SpeechRecognitionHelper: NSObject, SFSpeechRecognitionTaskDelegate {
    private var continuation: CheckedContinuation<SFTranscription?, Never>?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func transcribe(request: SFSpeechURLRecognitionRequest, recognizer: SFSpeechRecognizer) async -> SFTranscription? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
        }
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
        continuation?.resume(returning: result.bestTranscription)
        continuation = nil
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if !successfully {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didCompleteError error: Error) {
        print("❌ Transcription error: \(error.localizedDescription)")
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: String
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search for a place...", text: $searchText)
                        .onSubmit {
                            searchForLocation()
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Map View (using iOS 17+ Map API)
                if let mapItem = selectedMapItem {
                    Map {
                        Marker(
                            "Location",
                            coordinate: mapItem.placemark.coordinate
                        )
                        .tint(.purple)
                    }
                    .mapStyle(.standard)
                    .frame(height: 300)
                    .onAppear {
                        // Update region to center on the marker
                        region = MKCoordinateRegion(
                            center: mapItem.placemark.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                } else {
                    Map {
                        // Empty map
                    }
                    .mapStyle(.standard)
                    .frame(height: 300)
                }
                
                // Search Results
                if !searchResults.isEmpty {
                    List {
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                selectedMapItem = item
                                let placemark = item.placemark
                                selectedLocation = [
                                    placemark.name,
                                    placemark.locality,
                                    placemark.administrativeArea
                                ].compactMap { $0 }.joined(separator: ", ")
                                
                                // Update map region
                                region = MKCoordinateRegion(
                                    center: placemark.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.placemark.name ?? "Unknown")
                                        .font(.headline)
                                    if let address = formatAddress(from: item.placemark) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                } else {
                    // Current Location Button
                    VStack(spacing: 16) {
                        Button(action: {
                            locationManager.requestLocation { location in
                                let geocoder = CLGeocoder()
                                geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                                    if let placemark = placemarks?.first {
                                        selectedLocation = [
                                            placemark.name,
                                            placemark.locality,
                                            placemark.administrativeArea
                                        ].compactMap { $0 }.joined(separator: ", ")
                                        
                                        // Update map region
                                        region = MKCoordinateRegion(
                                            center: location.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        )
                                        
                                        // Create map item for display
                                        let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                                        selectedMapItem = mapItem
                                        
                                        dismiss()
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Use Current Location")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Text("Or search for a location above")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
                
                Spacer()
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func searchForLocation() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String? {
        var components: [String] = []
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct BibleVersePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedVerse: String
    @State private var reference = ""
    @State private var verseText = ""
    @State private var selectedCategory: VerseCategory = .all
    @State private var searchText = ""
    
    enum VerseCategory: String, CaseIterable {
        case all = "All Verses"
        case faith = "Faith & Salvation"
        case strength = "Strength & Courage"
        case peace = "Peace & Comfort"
        case love = "Love & Relationships"
        case prayer = "Prayer & Worship"
        case hope = "Hope & Encouragement"
        case wisdom = "Wisdom & Guidance"
        case gratitude = "Gratitude"
        case purpose = "God's Plans & Purpose"
    }
    
    // Popular Bible verses organized by category
    let popularVerses: [VerseCategory: [(reference: String, text: String)]] = [
        .faith: [
            ("John 3:16", "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."),
            ("Romans 10:9", "If you declare with your mouth, \"Jesus is Lord,\" and believe in your heart that God raised him from the dead, you will be saved."),
            ("Ephesians 2:8-9", "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast."),
            ("Acts 16:31", "They replied, \"Believe in the Lord Jesus, and you will be saved—you and your household.\""),
            ("Romans 3:23", "for all have sinned, and fall short of the glory of God;")
        ],
        .strength: [
            ("Philippians 4:13", "I can do all this through him who gives me strength."),
            ("Isaiah 40:31", "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint."),
            ("Joshua 1:9", "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go."),
            ("Deuteronomy 31:6", "Be strong and courageous. Do not be afraid or terrified because of them, for the Lord your God goes with you; he will never leave you nor forsake you."),
            ("2 Timothy 1:7", "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.")
        ],
        .peace: [
            ("John 14:27", "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid."),
            ("Philippians 4:6-7", "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus."),
            ("Matthew 11:28-30", "Come to me, all you who are weary and burdened, and I will give you rest. Take my yoke upon you and learn from me, for I am gentle and humble in heart, and you will find rest for your souls."),
            ("1 Peter 5:7", "Cast all your anxiety on him because he cares for you."),
            ("Psalm 23:1-4", "The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, he leads me beside quiet waters, he refreshes my soul.")
        ],
        .love: [
            ("1 Corinthians 13:4-7", "Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs."),
            ("1 John 4:7-8", "Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God. Whoever does not love does not know God, because God is love."),
            ("John 15:12", "My command is this: Love each other as I have loved you."),
            ("Romans 12:10", "Be devoted to one another in love. Honor one another above yourselves.")
        ],
        .prayer: [
            ("1 Thessalonians 5:16-18", "Rejoice always, pray continually, give thanks in all circumstances; for this is God's will for you in Christ Jesus."),
            ("Matthew 6:33", "But seek first his kingdom and his righteousness, and all these things will be given to you as well."),
            ("Psalm 100:4", "Enter his gates with thanksgiving and his courts with praise; give thanks to him and praise his name."),
            ("James 5:16", "Therefore confess your sins to each other and pray for each other so that you may be healed. The prayer of a righteous person is powerful and effective.")
        ],
        .hope: [
            ("Romans 15:13", "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit."),
            ("Lamentations 3:22-23", "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness."),
            ("Psalm 27:1", "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid?"),
            ("2 Corinthians 4:16-18", "Therefore we do not lose heart. Though outwardly we are wasting away, yet inwardly we are being renewed day by day.")
        ],
        .wisdom: [
            ("James 1:5", "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you."),
            ("Psalm 119:105", "Your word is a lamp for my feet, a light on my path."),
            ("Proverbs 16:3", "Commit to the Lord whatever you do, and he will establish your plans."),
            ("Isaiah 30:21", "Whether you turn to the right or to the left, your ears will hear a voice behind you, saying, \"This is the way; walk in it.\"")
        ],
        .gratitude: [
            ("Psalm 136:1", "Give thanks to the Lord, for he is good. His love endures forever."),
            ("Colossians 3:15", "Let the peace of Christ rule in your hearts, since as members of one body you were called to peace. And be thankful."),
            ("Psalm 107:1", "Give thanks to the Lord, for he is good; his love endures forever."),
            ("1 Chronicles 16:34", "Give thanks to the Lord, for he is good; his love endures forever.")
        ],
        .purpose: [
            ("Jeremiah 29:11", "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future."),
            ("Romans 8:28", "And we know that in all things God works for the good of those who love him, who have been called according to his purpose."),
            ("Proverbs 3:5-6", "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."),
            ("Psalm 37:4", "Take delight in the Lord, and he will give you the desires of your heart.")
        ]
    ]
    
    var filteredVerses: [(reference: String, text: String)] {
        let verses = selectedCategory == .all ? 
            popularVerses.values.flatMap { $0 } : 
            (popularVerses[selectedCategory] ?? [])
        
        if searchText.isEmpty {
            return verses
        } else {
            return verses.filter { verse in
                verse.reference.localizedCaseInsensitiveContains(searchText) ||
                verse.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                #if os(macOS)
                // Dropdown on macOS — horizontal scroll unreliable
                Picker("Category", selection: $selectedCategory) {
                    ForEach(VerseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                #else
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 12) {
                        ForEach(VerseCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .font(.body.weight(selectedCategory == category ? .semibold : .regular))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.purple : Color(.systemGray6))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                #endif
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search verses...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Verse List
                List {
                    ForEach(Array(filteredVerses.enumerated()), id: \.offset) { _, verse in
                        Button(action: {
                            selectedVerse = "\(verse.reference): \(verse.text)"
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verse.reference)
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                Text(verse.text)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Manual Entry Section
                    Section("Or Enter Manually") {
                        TextField("Bible Reference (e.g., John 3:16)", text: $reference)
                        TextEditor(text: $verseText)
                            .frame(height: 100)
                            .overlay(
                                Group {
                                    if verseText.isEmpty {
                                        Text("Enter verse text...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                        Button("Add Manual Verse") {
                            if !reference.isEmpty && !verseText.isEmpty {
                                selectedVerse = "\(reference): \(verseText)"
                                dismiss()
                            }
                        }
                        .disabled(reference.isEmpty || verseText.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                #if os(macOS)
                .scrollContentBackground(.hidden)
                .formStyle(.grouped)
                .padding(.horizontal, 20)
                #endif
            }
            .navigationTitle("Add Bible Verse")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Map Annotation Item (for Identifiable conformance)
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation(completion: @escaping (CLLocation) -> Void) {
        self.completion = completion
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            completion?(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: Double
}

@available(iOS 17.0, *)
struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    
    var shareText: String {
        """
        \(entry.title)
        
        \(entry.content)
        
        \(entry.date.formatted())
        Tags: \(entry.tags.joined(separator: ", "))
        """
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(entry.title)
                            .font(.title)
                            .font(.body.weight(.bold))
                        
                        Spacer()
                        
                        if entry.isPrivate {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    HStack {
                        Text(entry.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let mood = entry.mood {
                            Text("• \(mood)")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Content
                Text(entry.content)
                    .font(.body)
                    .lineSpacing(4)
                
                // Tags
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                        HStack(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Media Attachments
                if !entry.photoURLs.isEmpty || entry.audioURL != nil || entry.drawingData != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attachments")
                            .font(.headline)
                        
                        // Photos
                        if !entry.photoURLs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                                HStack(spacing: 8) {
                                    ForEach(entry.photoURLs, id: \.self) { url in
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        // Audio
                        if let audioURL = entry.audioURL {
                            AudioPlayerView(audioURL: audioURL)
                        }
                        
                        // Drawing - Handle both PencilKit format and legacy UIImage format
                        if let drawingData = entry.drawingData {
                            if let drawing = try? PKDrawing(data: drawingData) {
                                // Render PencilKit drawing
                                PencilKitDrawingView(drawing: drawing)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                            } else if let uiImage = UIImage(data: drawingData) {
                                // Render legacy UIImage format
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Entry Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button("Edit") { showingEditSheet = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            JournalActivityView(activityItems: [shareText])
        }
        .sheet(isPresented: $showingEditSheet) {
            NewJournalEntryView(entry: entry)
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                let entryToDelete = entry // Capture entry before deletion
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                    
                    // Sync deletion to Firebase for cross-device sync
                    Task {
                        await FirebaseSyncService.shared.deleteJournalEntry(entryToDelete)
                        print("✅ [FIREBASE] Entry deletion synced to Firebase")
                    }
                } catch {
                    print("❌ Error deleting entry: \(error.localizedDescription)")
                    ErrorHandler.shared.handle(.deleteFailed)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
}

@available(iOS 17.0, *)
struct AudioPlayerView: View {
    let audioURL: URL
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Recording")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatAudioTime(currentTime) + " / " + formatAudioTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    if duration > 0 {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(currentTime / duration), height: 4)
                            .cornerRadius(2)
                    }
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            
            // Set up delegate to handle playback completion
            let delegate = AudioPlayerDelegate(onFinish: {
                DispatchQueue.main.async {
                    isPlaying = false
                    currentTime = 0
                    playbackTimer?.invalidate()
                }
            })
            audioPlayerDelegate = delegate
            audioPlayer?.delegate = delegate
        } catch {
            print("Audio player setup failed: \(error)")
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        audioPlayer?.play()
        isPlaying = true
        
        // Start timer to update progress
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                if currentTime >= duration {
                    isPlaying = false
                    currentTime = 0
                    playbackTimer?.invalidate()
                }
            }
        }
    }
    
    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        playbackTimer?.invalidate()
    }
    
    private func formatAudioTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper class for AVAudioPlayer delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

@available(iOS 17.0, *)
struct EditJournalEntryView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var content: String
    @State private var tags: String
    @State private var isPrivate: Bool
    @State private var selectedMood: String
    
    init(entry: JournalEntry) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _content = State(initialValue: entry.content)
        _tags = State(initialValue: entry.tags.joined(separator: ", "))
        _isPrivate = State(initialValue: entry.isPrivate)
        _selectedMood = State(initialValue: entry.mood ?? "")
    }
    
    let moods = ["", "Happy", "Grateful", "Peaceful", "Reflective", "Challenged", "Hopeful", "Anxious", "Joyful"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $title)
                }
                
                Section(header: Text("Content")) {
                    TextEditor(text: $content)
                        .frame(height: 120)
                }
                
                Section(header: Text("Mood")) {
                    Picker("How are you feeling?", selection: $selectedMood) {
                        Text("No mood selected").tag("")
                        ForEach(moods.dropFirst(), id: \.self) { mood in
                            Text(mood).tag(mood)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                
                Section {
                    Toggle("Private Entry", isOn: $isPrivate)
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        entry.title = title
        entry.content = content
        entry.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        entry.mood = selectedMood.isEmpty ? nil : selectedMood
        entry.isPrivate = isPrivate
        entry.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Error saving journal entry changes: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, *)
struct JournalSearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: JournalFilter
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search entries...", text: $searchText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            HStack {
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedFilter == .all) {
                            selectedFilter = .all
                        }
                        FilterChip(title: "Private", isSelected: selectedFilter == .private) {
                            selectedFilter = .private
                        }
                        FilterChip(title: "With Media", isSelected: selectedFilter == .withMedia) {
                            selectedFilter = .withMedia
                        }
                        FilterChip(title: "Happy", isSelected: selectedFilter == .mood("Happy")) {
                            selectedFilter = .mood("Happy")
                        }
                        FilterChip(title: "Grateful", isSelected: selectedFilter == .mood("Grateful")) {
                            selectedFilter = .mood("Grateful")
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct JournalEntriesList: View {
    let entries: [JournalEntry]
    let deleteEntry: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(destination: JournalEntryDetailView(entry: entry)) {
                    JournalEntryRow(entry: entry)
                }
            }
            .onDelete(perform: deleteEntry)
        }
        .listStyle(PlainListStyle())
    }
}

// Helper view to render PencilKit drawings in read-only mode
struct PencilKitDrawingView: UIViewRepresentable {
    let drawing: PKDrawing
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.isUserInteractionEnabled = false // Read-only
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
}

// MARK: - JournalActivityView for Sharing (to avoid conflict with SettingsView.ActivityView)
struct JournalActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 