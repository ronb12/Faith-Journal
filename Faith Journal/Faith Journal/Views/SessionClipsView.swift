//
//  SessionClipsView.swift
//  Faith Journal
//
//  Full UI for creating, viewing, and managing session clips
//

import SwiftUI
import SwiftData
import AVKit

@available(iOS 17.0, *)
struct SessionClipsView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var clips: [SessionClip]
    @State private var showingCreateClip = false
    @State private var selectedClip: SessionClip?
    @State private var showingClipPlayer = false
    
    private let userService = LocalUserService.shared
    
    var sessionClips: [SessionClip] {
        clips.filter { $0.sessionId == session.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var isHost: Bool {
        session.hostId == userService.userIdentifier
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.platformSystemGroupedBackground.ignoresSafeArea()
                
                if sessionClips.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "scissors")
                            .font(.system(size: 60))
                            .foregroundColor(.purple.opacity(0.5))
                        
                        Text("No Clips Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create shareable highlights from this session's recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if let recordingURL = session.recordingURL, !recordingURL.isEmpty {
                            Button(action: { showingCreateClip = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create First Clip")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 200)
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        } else {
                            Text("Recordings will be available after the session ends")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Create clip button
                            if let recordingURL = session.recordingURL, !recordingURL.isEmpty {
                                Button(action: { showingCreateClip = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Create New Clip")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Clips grid
                            ForEach(sessionClips) { clip in
                                ClipCard(clip: clip) {
                                    selectedClip = clip
                                    showingClipPlayer = true
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Session Clips")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
            .sheet(isPresented: $showingCreateClip) {
                if let recordingURL = session.recordingURL, !recordingURL.isEmpty {
                    CreateClipView(session: session, recordingURL: recordingURL)
                }
            }
            .sheet(item: $selectedClip) { clip in
                ClipPlayerView(clip: clip)
            }
        }
    }
}

@available(iOS 17.0, *)
struct ClipCard: View {
    let clip: SessionClip
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.2))
                        .frame(height: 200)
                    
                    if let thumbnailURL = clip.thumbnailURL, !thumbnailURL.isEmpty {
                        AsyncImage(url: URL(string: thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.purple.opacity(0.5))
                        }
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                    } else {
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.purple.opacity(0.5))
                            Text(formatDuration(clip.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                
                // Clip info
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !clip.clipDescription.isEmpty {
                        Text(clip.clipDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Label("\(clip.viewCount)", systemImage: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Label("\(clip.shareCount)", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(clip.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.platformSystemBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@available(iOS 17.0, *)
struct CreateClipView: View {
    let session: LiveSession
    let recordingURL: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var clipTitle = ""
    @State private var clipDescription = ""
    @State private var startTime: Double = 0
    @State private var endTime: Double = 60
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private let userService = LocalUserService.shared
    private let highlightsService = StreamHighlightsService.shared
    private let maxClipDuration: Double = 300 // 5 minutes max
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Clip Title", text: $clipTitle)
                    TextField("Description (optional)", text: $clipDescription, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Clip Details")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start Time: \(formatTime(startTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $startTime, in: 0...max(endTime - 10, 0), step: 1) {
                            Text("Start")
                        }
                        
                        Text("End Time: \(formatTime(endTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $endTime, in: min(startTime + 10, maxClipDuration)...maxClipDuration, step: 1) {
                            Text("End")
                        }
                        
                        Text("Duration: \(formatDuration(endTime - startTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Time Range")
                } footer: {
                    Text("Select the portion of the recording to include in this clip (max 5 minutes)")
                }
            }
            .navigationTitle("Create Clip")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createClip()
                    }
                    .disabled(clipTitle.isEmpty || isCreating)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createClip()
                    }
                    .disabled(clipTitle.isEmpty || isCreating)
                }
                #endif
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func createClip() {
        guard !clipTitle.isEmpty else { return }
        guard endTime > startTime else {
            errorMessage = "End time must be after start time"
            return
        }
        
        guard endTime - startTime <= maxClipDuration else {
            errorMessage = "Clip duration cannot exceed 5 minutes"
            return
        }
        
        guard let recordingURLString = session.recordingURL,
              !recordingURLString.isEmpty,
              let recordingURL = URL(string: recordingURLString) else {
            errorMessage = "Recording not available"
            return
        }
        
        isCreating = true
        
        let userId = userService.userIdentifier
        let duration = endTime - startTime
        
        // Generate clip from recording URL using StreamHighlightsService
        Task { @MainActor in
            do {
                // Generate the actual video clip file
                let clipFileURL = try await highlightsService.generateClip(
                    from: recordingURL,
                    startTime: startTime,
                    duration: duration
                )
                
                // Create clip metadata with generated clip URL
                let clip = SessionClip(
                    sessionId: session.id,
                    title: clipTitle,
                    startTime: startTime,
                    endTime: endTime,
                    createdBy: userId,
                    description: clipDescription
                )
                
                // Store the generated clip file URL
                clip.clipURL = clipFileURL.absoluteString
                
                // Optionally save thumbnail (could be generated from first frame)
                // For now, thumbnail is optional
                
                modelContext.insert(clip)
                
                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    errorMessage = "Failed to save clip: \(error.localizedDescription)"
                    isCreating = false
                }
            } catch {
                errorMessage = "Failed to generate clip: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
}

@available(iOS 17.0, *)
struct ClipPlayerView: View {
    let clip: SessionClip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if let player = player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle(clip.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: shareableURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: shareableURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                setupPlayer()
                incrementViewCount()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
    
    private var shareableURL: URL {
        // Return the actual clip file URL if available
        if let clipURL = URL(string: clip.clipURL), !clip.clipURL.isEmpty {
            // Check if it's a local file URL or remote URL
            if clipURL.isFileURL {
                return clipURL
            } else {
                // Remote URL - use as-is
                return clipURL
            }
        }
        // Fallback for clips without URL (shouldn't happen in normal flow)
        return URL(string: "https://faith-journal.web.app/clips/\(clip.id)") ?? URL(string: "https://faith-journal.web.app")!
    }
    
    private func setupPlayer() {
        guard let clipURL = URL(string: clip.clipURL), !clip.clipURL.isEmpty else {
            errorMessage = "Clip video not available"
            return
        }
        
        let asset = AVAsset(url: clipURL)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: clip.startTime, preferredTimescale: 600),
            duration: CMTime(seconds: clip.duration, preferredTimescale: 600)
        )
        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            request.finish(with: request.sourceImage, context: nil)
        })
        
        player = AVPlayer(playerItem: playerItem)
        player?.seek(to: timeRange.start)
        player?.play()
    }
    
    private func incrementViewCount() {
        clip.viewCount += 1
        try? modelContext.save()
    }
}
