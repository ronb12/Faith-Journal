import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
            filtered = filtered.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .private:
            filtered = filtered.filter { $0.isPrivate }
        case .public:
            filtered = filtered.filter { !$0.isPrivate }
        case .withMedia:
            filtered = filtered.filter { !$0.photoURLs.isEmpty || $0.audioURL != nil || $0.drawingData != nil }
        case .mood(let mood):
            filtered = filtered.filter { $0.mood == mood }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search entries...", text: $searchText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.platformSystemGray6)
                    .cornerRadius(10)
                    
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All", isSelected: selectedFilter == JournalFilter.all, selectedColor: .blue) {
                                    selectedFilter = .all
                                }
                                FilterChip(title: "Private", isSelected: selectedFilter == JournalFilter.private, selectedColor: .blue) {
                                    selectedFilter = .private
                                }
                                FilterChip(title: "With Media", isSelected: selectedFilter == JournalFilter.withMedia, selectedColor: .blue) {
                                    selectedFilter = .withMedia
                                }
                                FilterChip(title: "Happy", isSelected: selectedFilter == JournalFilter.mood("Happy"), selectedColor: .blue) {
                                    selectedFilter = .mood("Happy")
                                }
                                FilterChip(title: "Grateful", isSelected: selectedFilter == JournalFilter.mood("Grateful"), selectedColor: .blue) {
                                    selectedFilter = .mood("Grateful")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color.platformSystemBackground)
                
                // Entries List
                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(destination: JournalEntryDetailView(entry: entry)) {
                            JournalEntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntry)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Journal")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
#endif
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            let entry = filteredEntries[index]
            modelContext.delete(entry)
        }
        try? modelContext.save()
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
    
    let moods = ["", "Happy", "Grateful", "Peaceful", "Reflective", "Challenged", "Hopeful", "Anxious", "Joyful"]
    
    var body: some View {
        NavigationView {
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
#if os(iOS)
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
#endif
                    
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
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntry() }
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
#endif
        }
        .sheet(isPresented: $showingDrawingSheet) {
            DrawingView(drawingData: $drawingData)
        }
#if os(iOS)
        .onAppear {
            setupAudioRecorder()
        }
#endif
    }
    
    #if os(iOS)
    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioFileName = "\(UUID().uuidString).m4a"
            audioURL = documentsPath.appendingPathComponent(audioFileName)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL!, settings: settings)
        } catch {
            print("Audio recorder setup failed: \(error)")
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
    #else
    private func setupAudioRecorder() {}
    
    private func toggleRecording() {}
    #endif
    
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
        try? modelContext.save()
        dismiss()
    }
}

struct DrawingView: View {
    @Binding var drawingData: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var lines: [Line] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Canvas { context, size in
                    for line in lines {
                        var path = Path()
                        path.addLines(line.points)
                        context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
                    }
                }
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let position = value.location
                        if value.translation == .zero {
                            lines.append(Line(points: [position], color: .black, lineWidth: 3))
                        } else if let lastIdx = lines.indices.last {
                            lines[lastIdx].points.append(position)
                        }
                    }
                )
                .background(Color.white)
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("Drawing")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Convert drawing to data
                        let renderer = ImageRenderer(content: DrawingCanvas(lines: lines))
                        if let image = renderer.uiImage {
                            drawingData = image.jpegData(compressionQuality: 0.8)
                        }
                        dismiss()
                    }
                }
            }
#endif
        }
    }
}

struct DrawingCanvas: View {
    let lines: [Line]
    
    var body: some View {
        Canvas { context, size in
            for line in lines {
                var path = Path()
                path.addLines(line.points)
                context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
            }
        }
        .background(Color.white)
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
                        
                        // Drawing
#if os(iOS)
                        if let drawingData = entry.drawingData,
                           let uiImage = UIImage(data: drawingData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
#else
                        if let drawingData = entry.drawingData,
                           let nsImage = NSImage(data: drawingData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
#endif
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Entry Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") { showingEditSheet = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
#endif
        .sheet(isPresented: $showingEditSheet) {
            EditJournalEntryView(entry: entry)
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
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
        .background(Color.platformSystemGray6)
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
        NavigationView {
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
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
#endif
        }
    }
    
    private func saveChanges() {
        entry.title = title
        entry.content = content
        entry.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        entry.mood = selectedMood.isEmpty ? nil : selectedMood
        entry.isPrivate = isPrivate
        entry.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
} 