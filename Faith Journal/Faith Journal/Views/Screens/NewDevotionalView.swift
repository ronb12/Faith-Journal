import SwiftUI
import PhotosUI
import AVFoundation
import SwiftData
import UIKit

struct NewDevotionalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var scripture = ""
    @State private var reflection = ""
    @State private var mood: String?
    @State private var relatedVerses: [String] = [""]
    @State private var prayerPoints: [String] = [""]
    @State private var tags: [String] = []
    @State private var isPrivate = false
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isRecording = false
    @State private var audioURL: URL?
    
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingSession: AVAudioSession?
    
    @State private var showingTagSheet = false
    @State private var newTag = ""
    
    // Mood Section
    private var moodSection: some View {
        Section("Mood") {
            TextField("How are you feeling?", text: .init(
                get: { mood ?? "" },
                set: { mood = $0.isEmpty ? nil : $0 }
            ))
        }
    }
    
    // Related Verses Section
    private var relatedVersesSection: some View {
        Section("Related Verses") {
            ForEach($relatedVerses.indices, id: \ .self) { index in
                TextField("Verse reference", text: $relatedVerses[index])
            }
            
            Button("Add Verse") {
                relatedVerses.append("")
            }
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
            Section {
                TextField("Title", text: $title)
                TextField("Scripture Reference", text: $scripture)
                TextEditor(text: $reflection)
                    .frame(height: 150)
            }
            
            moodSection
            
            relatedVersesSection
            
            prayerPointsSection
            
            tagsSection
            
            mediaSection
            
            Section {
                Toggle("Private Entry", isOn: $isPrivate)
            }
        }
        .navigationTitle("New Devotional")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveDevotional()
                }
                .disabled(title.isEmpty || scripture.isEmpty || reflection.isEmpty)
            }
        }
        .sheet(isPresented: $showingTagSheet) {
            tagManagementSheetView
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
    
    private func saveDevotional() {
        let devotional = Devotional(
            title: title,
            scripture: scripture,
            reflection: reflection,
            tags: tags,
            mood: mood,
            imageData: imageData,
            audioURL: audioURL,
            isPrivate: isPrivate,
            relatedVerses: relatedVerses.filter { !$0.isEmpty },
            prayerPoints: prayerPoints.filter { !$0.isEmpty }
        )
        
        modelContext.insert(devotional)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewDevotionalView()
    }
} 