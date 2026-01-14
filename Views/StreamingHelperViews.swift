//
//  StreamingHelperViews.swift
//  Faith Journal
//
//  Helper views for live streaming features
//

import SwiftUI

// MARK: - Participant Thumbnail

@available(iOS 17.0, *)
struct ParticipantThumbnail: View {
    let participant: LiveStreamView.ParticipantInfo
    let isSpotlighted: Bool
    let onSpotlight: () -> Void
    let onMute: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                // Status indicators
                VStack {
                    HStack {
                        if participant.isMuted {
                            Image(systemName: "mic.slash.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
            }
            
            Text(participant.name)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Speaking indicator
            if participant.isSpeaking {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 70)
        .padding(8)
        .background(isSpotlighted ? Color.orange.opacity(0.3) : Color.clear)
        .cornerRadius(12)
        .onTapGesture {
            onSpotlight()
        }
        .contextMenu {
            Button(action: onMute) {
                Label(participant.isMuted ? "Unmute" : "Mute", systemImage: participant.isMuted ? "mic.fill" : "mic.slash.fill")
            }
            Button(action: onSpotlight) {
                Label(isSpotlighted ? "Remove Spotlight" : "Spotlight", systemImage: "star.fill")
            }
        }
    }
}

// MARK: - Participant Grid View

@available(iOS 17.0, *)
struct ParticipantGridView: View {
    let participants: [LiveStreamView.ParticipantInfo]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(participants) { participant in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple)
                                
                                if participant.isMuted {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "mic.slash.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .padding(6)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                            
                            Text(participant.name)
                                .font(.headline)
                            
                            HStack(spacing: 8) {
                                if participant.isMuted {
                                    Label("Muted", systemImage: "mic.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                if !participant.isVideoEnabled {
                                    Label("Video Off", systemImage: "video.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                if participant.isSpeaking {
                                    Label("Speaking", systemImage: "waveform")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Whiteboard View

struct WhiteboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drawings: [Drawing] = []
    
    struct Drawing: Identifiable {
        let id = UUID()
        var points: [CGPoint] = []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                
                // Drawing canvas
                Canvas { context, size in
                    for drawing in drawings {
                        var path = Path()
                        if let firstPoint = drawing.points.first {
                            path.move(to: firstPoint)
                            for point in drawing.points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        context.stroke(path, with: .color(.black), lineWidth: 3)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if drawings.isEmpty {
                                drawings.append(Drawing())
                            }
                            drawings[drawings.count - 1].points.append(value.location)
                        }
                )
            }
            .navigationTitle("Whiteboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        drawings.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Breakout Rooms View

struct BreakoutRoomsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rooms: [BreakoutRoom] = []
    
    struct BreakoutRoom: Identifiable {
        let id = UUID()
        var name: String
        var participants: [String] = []
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(rooms) { room in
                    Section(header: Text(room.name)) {
                        ForEach(room.participants, id: \.self) { participant in
                            Text(participant)
                        }
                    }
                }
                
                Button(action: createRoom) {
                    Label("Create Breakout Room", systemImage: "plus.circle")
                }
            }
            .navigationTitle("Breakout Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func createRoom() {
        let room = BreakoutRoom(name: "Room \(rooms.count + 1)")
        rooms.append(room)
    }
}


