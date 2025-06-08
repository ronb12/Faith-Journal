import SwiftUI
import PhotosUI

struct NewJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isRecording = false
    @State private var showingMoodPicker = false
    @State private var selectedMood: Mood?
    @State private var isPrivate = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                Section("Media") {
                    PhotosPicker(selection: $selectedPhotos, matching: .images) {
                        Label("Add Photos", systemImage: "photo")
                    }
                    
                    Button {
                        isRecording.toggle()
                    } label: {
                        Label(isRecording ? "Stop Recording" : "Record Audio", 
                              systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    }
                    .foregroundStyle(isRecording ? .red : .blue)
                }
                
                Section {
                    Button {
                        showingMoodPicker = true
                    } label: {
                        HStack {
                            Text("Mood")
                            Spacer()
                            if let mood = selectedMood {
                                Text(mood.rawValue)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Toggle("Private Entry", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save entry
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMoodPicker) {
                MoodPickerView(selectedMood: $selectedMood)
            }
        }
    }
}

enum Mood: String, CaseIterable {
    case joyful = "Joyful"
    case peaceful = "Peaceful"
    case grateful = "Grateful"
    case hopeful = "Hopeful"
    case reflective = "Reflective"
    case challenged = "Challenged"
    case anxious = "Anxious"
    case sad = "Sad"
}

struct MoodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMood: Mood?
    
    var body: some View {
        NavigationStack {
            List(Mood.allCases, id: \.self) { mood in
                Button {
                    selectedMood = mood
                    dismiss()
                } label: {
                    Text(mood.rawValue)
                }
            }
            .navigationTitle("Select Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NewJournalEntryView()
} 