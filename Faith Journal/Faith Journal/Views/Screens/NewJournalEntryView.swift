import SwiftUI
import PhotosUI
import PencilKit
import AVFoundation
import SwiftData

struct NewJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var mood: String?
    @State private var location: String?
    @State private var bibleReference = ""
    @State private var prayerPoints: [String] = [""]
    @State private var tags: [String] = []
    @State private var isPrivate = false
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isRecording = false
    @State private var audioURL: URL?
    @State private var canvasView = PKCanvasView()
    @State private var drawingData: Data?
    
    @State private var showingImagePicker = false
    @State private var showingDrawingSheet = false
    @State private var showingTagSheet = false
    @State private var newTag = ""
    
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingSession: AVAudioSession?
    
    // Title and Content Section
    private var titleAndContentSection: some View {
        Section {
            TextField("Title", text: $title)
            TextEditor(text: $content)
                .frame(height: 150)
        }
    }
    
    // Mood & Location Section
    private var moodAndLocationSection: some View {
        Section("Mood & Location") {
            TextField("How are you feeling?", text: .init(
                get: { mood ?? "" },
                set: { mood = $0.isEmpty ? nil : $0 }
            ))
            
            TextField("Location", text: .init(
                get: { location ?? "" },
                set: { location = $0.isEmpty ? nil : $0 }
            ))
        }
    }
    
    // Bible Reference Section
    private var bibleReferenceSection: some View {
        Section("Bible Reference") {
            TextField("Enter verse reference", text: $bibleReference)
        }
    }
    
    // Prayer Points Section
    private var prayerPointsSection: some View {
        Section("Prayer Points") {
            ForEach($prayerPoints.indices, id: \ .self) { index in
                TextField("Prayer point", text: $prayerPoints[index])
            }
            
            Button("Add Prayer Point") {
                prayerPoints.append("")
            }
        }
    }
    
    // Tags Section
    private var tagsSection: some View {
        Section("Tags") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Button("Manage Tags") {
                showingTagSheet = true
            }
        }
    }
    
    // Media Section
    private var mediaSection: some View {
        Section("Media") {
            HStack {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                }
                
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Label(isRecording ? "Stop Recording" : "Record Audio", 
                          systemImage: isRecording ? "stop.circle" : "mic")
                }
                
                Button {
                    showingDrawingSheet = true
                } label: {
                    Label("Add Drawing", systemImage: "pencil.tip")
                }
            }
            
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }
            
            if audioURL != nil {
                Label("Audio Recording Added", systemImage: "waveform")
            }
            
            if drawingData != nil {
                Label("Drawing Added", systemImage: "pencil.tip")
            }
        }
    }
    
    private func setupAudioRecording() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        } catch {
            print("Failed to setup audio recording: \(error)")
        }
    }
    
    private func startRecording() {
        if audioRecorder == nil {
            setupAudioRecording()
        }
        
        audioRecorder?.record()
        isRecording = true
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        audioURL = audioRecorder?.url
        isRecording = false
    }
    
    // Tag Management Sheet View
    private var tagManagementSheetView: some View {
        NavigationStack {
            List {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                }
                
                HStack {
                    TextField("New tag", text: $newTag)
                    
                    Button("Add") {
                        if !newTag.isEmpty && !tags.contains(newTag) {
                            tags.append(newTag)
                            newTag = ""
                        }
                    }
                }
            }
            .navigationTitle("Manage Tags")
            .toolbar {
                Button("Done") {
                    showingTagSheet = false
                }
            }
        }
    }
    
    var body: some View {
        Form {
            titleAndContentSection
            
            moodAndLocationSection
            
            bibleReferenceSection
            
            prayerPointsSection
            
            tagsSection
            
            mediaSection
            
            Section {
                Toggle("Private Entry", isOn: $isPrivate)
            }
        }
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveEntry()
                }
                .disabled(title.isEmpty || content.isEmpty)
            }
        }
        .sheet(isPresented: $showingTagSheet) {
            tagManagementSheetView
        }
        .sheet(isPresented: $showingDrawingSheet) {
            DrawingView(drawingData: $drawingData)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    imageData = data
                }
            }
        }
        .onAppear {
            setupAudioRecording()
        }
        .onDisappear {
            audioRecorder?.stop()
            try? recordingSession?.setActive(false)
        }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            title: title,
            content: content,
            mood: mood,
            location: location,
            imageData: imageData,
            audioURL: audioURL,
            drawingData: drawingData,
            bibleReference: bibleReference.isEmpty ? nil : bibleReference,
            prayerPoints: prayerPoints.filter { !$0.isEmpty },
            tags: tags,
            isPrivate: isPrivate
        )
        
        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewJournalEntryView()
    }
} 