import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import PencilKit

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
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Start your faith journey by creating your first journal entry")
                            .font(.body)
                            .foregroundColor(.secondary)
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
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            guard index < filteredEntries.count else { continue }
            let entry = filteredEntries[index]
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
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
                        .foregroundColor(.secondary)
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
                .foregroundColor(themeManager.colors.textSecondary)
            
            HStack {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                
                if let mood = entry.mood {
                    Text("• \(mood)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
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

struct NewJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var isPrivate = false
    @State private var selectedMood: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [URL] = []
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioURL: URL?
    @State private var showingDrawingSheet = false
    @State private var drawingData: Data?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
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
                
                Section(header: Text("Media")) {
                    // Photo Picker
                    PhotosPicker(selection: $selectedPhotos, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Add Photos")
                        }
                    }
                    .onChange(of: selectedPhotos) { _, newValue in
                        Task {
                            photoURLs = []
                            for item in newValue {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                    let fileName = "\(UUID().uuidString).jpg"
                                    let fileURL = documentsPath.appendingPathComponent(fileName)
                                    try? data.write(to: fileURL)
                                    photoURLs.append(fileURL)
                                }
                            }
                        }
                    }
                    
                    // Audio Recording
                    HStack {
                        Button(action: toggleRecording) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
                                    .foregroundColor(isRecording ? .red : .blue)
                                Text(isRecording ? "Stop Recording" : "Record Audio")
                            }
                        }
                        
                        if audioURL != nil {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Drawing
                    Button(action: { showingDrawingSheet = true }) {
                        HStack {
                            Image(systemName: "pencil.tip")
                            Text("Add Drawing")
                        }
                    }
                }
                
                Section {
                    Toggle("Private Entry", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntry() }
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingDrawingSheet) {
            DrawingView(drawingData: $drawingData)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupAudioRecorder()
        }
    }
    
    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                errorMessage = "Cannot access documents directory for audio recording."
                showingErrorAlert = true
                return
            }
            
            let audioFileName = "\(UUID().uuidString).m4a"
            let audioFileURL = documentsPath.appendingPathComponent(audioFileName)
            audioURL = audioFileURL
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            guard let audioURL = audioURL else {
                errorMessage = "Failed to create audio file URL."
                showingErrorAlert = true
                return
            }
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        } catch {
            print("❌ Audio recorder setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to setup audio recorder: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            audioRecorder?.stop()
            isRecording = false
        } else {
            audioRecorder?.record()
            isRecording = true
        }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            title: title,
            content: content,
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            mood: selectedMood.isEmpty ? nil : selectedMood,
            location: nil,
            isPrivate: isPrivate
        )
        
        // Add media attachments
        entry.photoURLs = photoURLs
        entry.audioURL = audioURL
        entry.drawingData = drawingData
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Error saving journal entry: \(error.localizedDescription)")
            errorMessage = "Failed to save journal entry. Please try again.\n\n\(error.localizedDescription)"
            showingErrorAlert = true
            // Remove entry if save failed
            modelContext.delete(entry)
        }
    }
}

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: Double
}

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
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if entry.isPrivate {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
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
                    ScrollView(.horizontal, showsIndicators: false) {
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
                            ScrollView(.horizontal, showsIndicators: false) {
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
            ActivityView(activityItems: [shareText])
        }
        .sheet(isPresented: $showingEditSheet) {
            EditJournalEntryView(entry: entry)
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                do {
                    try modelContext.save()
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

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        HStack {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Text("Audio Recording")
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            setupAudioPlayer()
        }
    }
    
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Audio player setup failed: \(error)")
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
}

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
                ScrollView(.horizontal, showsIndicators: false) {
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