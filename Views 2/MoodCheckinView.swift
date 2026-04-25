//
//  MoodCheckinView.swift
//  Faith Journal
//
//  Enhanced mood check-in view with all features
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import PhotosUI

@available(iOS 17.0, *)
struct MoodCheckinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) private var journalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) private var prayerRequests: [PrayerRequest]
    
    @State private var selectedMood = "Grateful"
    @State private var intensity: Int = 5
    @State private var notes: String = ""
    @State private var tags: [String] = []
    @State private var selectedEmoji = "😊"
    @State private var moodCategory = "Neutral"
    @State private var activities: [String] = []
    @State private var energyLevel: Int = 5
    @State private var sleepQuality: Int?
    @State private var location: String?
    @State private var weather: String?
    @State private var triggers: [String] = []
    @State private var linkedJournalEntryId: UUID?
    @State private var linkedPrayerRequestIds: [UUID] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLocationPicker = false
    @State private var showingJournalLink = false
    @State private var showingPrayerLink = false
    @State private var isSaving = false
    
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let moods = ["Happy", "Grateful", "Peaceful", "Reflective", "Challenged", "Hopeful", "Anxious", "Joyful", "Sad", "Frustrated", "Content", "Excited", "Calm", "Worried", "Thankful", "Overwhelmed", "Blessed", "Stressed", "Loved", "Lonely"]
    
    let moodEmojis: [String: String] = [
        "Happy": "😊", "Grateful": "🙏", "Peaceful": "☮️", "Reflective": "🤔",
        "Challenged": "💪", "Hopeful": "✨", "Anxious": "😰", "Joyful": "😄",
        "Sad": "😢", "Frustrated": "😤", "Content": "😌", "Excited": "🎉",
        "Calm": "🧘", "Worried": "😟", "Thankful": "🙌", "Overwhelmed": "😵",
        "Blessed": "🙏", "Stressed": "😫", "Loved": "❤️", "Lonely": "😔"
    ]
    
    let availableActivities = ["Prayer", "Bible Reading", "Meditation", "Worship", "Journaling", "Exercise", "Rest", "Social", "Work", "Study"]
    
    private var moodEmojiPickerView: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 16) {
                ForEach(Array(moodEmojis.keys.sorted()), id: \.self) { mood in
                    Button(action: {
                        selectedMood = mood
                        selectedEmoji = moodEmojis[mood] ?? "😊"
                        updateMoodCategory()
                    }) {
                        VStack(spacing: 8) {
                            Text(moodEmojis[mood] ?? "😊")
                                .font(.system(size: 40))
                            Text(mood)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 80, height: 100)
                        .background(selectedMood == mood ? themeManager.colors.primary.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMood == mood ? themeManager.colors.primary : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 120)
    }
    
    private var moodDropdownView: some View {
        Picker("How are you feeling?", selection: $selectedMood) {
            ForEach(Array(moodEmojis.keys.sorted()), id: \.self) { mood in
                Text("\(moodEmojis[mood] ?? "😊") \(mood)")
                    .tag(mood)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedMood) { _, newValue in
            selectedEmoji = moodEmojis[newValue] ?? "😊"
            updateMoodCategory()
        }
    }
    
    private var moodSectionRest: some View {
        Section(header: Text("How are you feeling?")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensity")
                        .font(.subheadline)
                    Spacer()
                    Text("\(intensity)/10")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.primary)
                }
                Slider(value: Binding(
                    get: { Double(intensity) },
                    set: { intensity = Int($0) }
                ), in: 1...10, step: 1)
                .tint(themeManager.colors.primary)
            }
            Picker("Category", selection: $moodCategory) {
                Text("Positive").tag("Positive")
                Text("Neutral").tag("Neutral")
                Text("Challenging").tag("Challenging")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    moodDropdownView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            #endif
            Form {
                #if os(macOS)
                moodSectionRest
                #else
                Section(header: Text("How are you feeling?")) {
                    moodEmojiPickerView
                        .listRowInsets(EdgeInsets())
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intensity")
                                .font(.subheadline)
                            Spacer()
                            Text("\(intensity)/10")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
                        }
                        Slider(value: Binding(
                            get: { Double(intensity) },
                            set: { intensity = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(themeManager.colors.primary)
                    }
                    
                    // Mood Category
                    Picker("Category", selection: $moodCategory) {
                        Text("Positive").tag("Positive")
                        Text("Neutral").tag("Neutral")
                        Text("Challenging").tag("Challenging")
                    }
                }
                #endif
                
                // Activities
                Section(header: Text("What were you doing?")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(availableActivities, id: \.self) { activity in
                            Button(action: {
                                if activities.contains(activity) {
                                    activities.removeAll { $0 == activity }
                                } else {
                                    activities.append(activity)
                                }
                            }) {
                                HStack {
                                    Image(systemName: activities.contains(activity) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(activities.contains(activity) ? themeManager.colors.primary : .secondary)
                                    Text(activity)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(activities.contains(activity) ? themeManager.colors.primary.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                
                // Energy & Sleep
                Section(header: Text("Energy & Sleep")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Energy Level")
                                .font(.subheadline)
                            Spacer()
                            Text("\(energyLevel)/10")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
                        }
                        Slider(value: Binding(
                            get: { Double(energyLevel) },
                            set: { energyLevel = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(themeManager.colors.primary)
                    }
                    
                    Toggle("Track Sleep Quality", isOn: Binding(
                        get: { sleepQuality != nil },
                        set: { if !$0 { sleepQuality = nil } else { sleepQuality = 5 } }
                    ))
                    
                    if sleepQuality != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sleep Quality")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(sleepQuality!)/10")
                                    .font(.headline)
                                    .foregroundColor(themeManager.colors.primary)
                            }
                            Slider(value: Binding(
                                get: { Double(sleepQuality!) },
                                set: { sleepQuality = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(themeManager.colors.primary)
                        }
                    }
                }
                
                // Context
                Section(header: Text("Context")) {
                    // Location
                    Button(action: { showingLocationPicker = true }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(themeManager.colors.primary)
                            Text(location ?? "Add Location")
                                .foregroundColor(location != nil ? .primary : .secondary)
                            Spacer()
                            if location != nil {
                                Button(action: { location = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Weather (simplified - would integrate with weather API)
                    TextField("Weather (optional)", text: Binding(
                        get: { weather ?? "" },
                        set: { weather = $0.isEmpty ? nil : $0 }
                    ))
                    
                    // Triggers
                    TextField("What triggered this mood? (optional)", text: Binding(
                        get: { triggers.joined(separator: ", ") },
                        set: { triggers = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
                
                // Link to Journal/Prayer
                Section(header: Text("Link to")) {
                    Button(action: { showingJournalLink = true }) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(themeManager.colors.primary)
                            Text(linkedJournalEntryId != nil ? "Linked to Journal Entry" : "Link to Journal Entry")
                            Spacer()
                            if linkedJournalEntryId != nil {
                                Button(action: { linkedJournalEntryId = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Button(action: { showingPrayerLink = true }) {
                        HStack {
                            Image(systemName: "hands.sparkles.fill")
                                .foregroundColor(themeManager.colors.primary)
                            Text("Link to Prayer Requests (\(linkedPrayerRequestIds.count))")
                            Spacer()
                            if !linkedPrayerRequestIds.isEmpty {
                                Button(action: { linkedPrayerRequestIds = [] }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Photo
                Section(header: Text("Photo (optional)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundColor(themeManager.colors.primary)
                            Text(photoData != nil ? "Change Photo" : "Add Photo")
                            Spacer()
                            if photoData != nil {
                                Button(action: {
                                    selectedPhoto = nil
                                    photoData = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                    
                    if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                }
                
                // Notes
                Section(header: Text("Notes (optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                // Tags
                Section(header: Text("Tags (optional)")) {
                    TextField("Add tags separated by commas", text: Binding(
                        get: { tags.joined(separator: ", ") },
                        set: { tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }
            #if os(macOS)
            }
            #endif
            .navigationTitle("Mood Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMoodEntry()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: Binding(
                    get: { location ?? "" },
                    set: { location = $0.isEmpty ? nil : $0 }
                ))
            }
            .sheet(isPresented: $showingJournalLink) {
                JournalLinkView(selectedEntryId: $linkedJournalEntryId, entries: journalEntries)
            }
            .sheet(isPresented: $showingPrayerLink) {
                PrayerLinkView(selectedIds: $linkedPrayerRequestIds, requests: prayerRequests)
            }
            .onAppear {
                selectedEmoji = moodEmojis[selectedMood] ?? "😊"
                updateMoodCategory()
                loadLocationAndWeather()
            }
        }
    }
    
    private func updateMoodCategory() {
        let positiveMoods = ["Happy", "Grateful", "Peaceful", "Hopeful", "Joyful", "Content", "Excited", "Calm", "Thankful", "Blessed", "Loved"]
        let challengingMoods = ["Challenged", "Anxious", "Sad", "Frustrated", "Worried", "Overwhelmed", "Stressed", "Lonely"]
        
        if positiveMoods.contains(selectedMood) {
            moodCategory = "Positive"
        } else if challengingMoods.contains(selectedMood) {
            moodCategory = "Challenging"
        } else {
            moodCategory = "Neutral"
        }
    }
    
    private func loadLocationAndWeather() {
        locationManager.requestLocation { location in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first, self.location == nil {
                    self.location = [
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                }
            }
            // Fetch real weather data using WeatherService
            if self.weather == nil {
                WeatherService.shared.fetchWeather(for: location) { result in
                    switch result {
                    case .success(let weatherString):
                        self.weather = weatherString
                    case .failure:
                        // Leave weather as nil if fetch fails
                        break
                    }
                }
            }
        }
    }
    
    private func saveMoodEntry() {
        isSaving = true
        
        let entry = MoodEntry(
            mood: selectedMood,
            intensity: intensity,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            moodCategory: moodCategory,
            emoji: selectedEmoji,
            activities: activities,
            energyLevel: energyLevel
        )
        
        entry.sleepQuality = sleepQuality
        entry.location = location
        entry.weather = weather
        entry.triggers = triggers
        entry.linkedJournalEntryId = linkedJournalEntryId
        entry.linkedPrayerRequestIds = linkedPrayerRequestIds
        
        // Save photo if available
        if let photoData = photoData {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photoURL = documentsPath.appendingPathComponent("\(entry.id.uuidString).jpg")
            try? photoData.write(to: photoURL)
            entry.photoURL = photoURL
        }
        
        // Get location coordinates
        locationManager.requestLocation { location in
            entry.latitude = location.coordinate.latitude
            entry.longitude = location.coordinate.longitude
        }
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncMoodEntry(entry)
                print("✅ [FIREBASE] Mood entry synced to Firebase")
            }
            
            isSaving = false
            dismiss()
        } catch {
            errorMessage = "Failed to save mood entry: \(error.localizedDescription)"
            showingError = true
            modelContext.delete(entry)
            isSaving = false
        }
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct JournalLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEntryId: UUID?
    let entries: [JournalEntry]
    
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
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Link to Journal Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct PrayerLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIds: [UUID]
    let requests: [PrayerRequest]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(requests.prefix(20)) { request in
                    Button(action: {
                        if selectedIds.contains(request.id) {
                            selectedIds.removeAll { $0 == request.id }
                        } else {
                            selectedIds.append(request.id)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(request.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(request.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedIds.contains(request.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link to Prayer Requests")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        MoodCheckinView()
            .modelContainer(for: [MoodEntry.self], inMemory: true)
    }
}

