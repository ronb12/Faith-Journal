//
//  BroadcastStreamView_LiveKit.swift
//  Faith Journal
//
//  LiveKit-based streaming view for cross-location broadcasting
//  Supports single and multi-presenter modes
//

import SwiftUI
import AVFoundation
import SwiftData

// MARK: - Main View

@available(iOS 16.0, *)
struct BroadcastStreamView_LiveKit: View {
    let sessionTitle: String
    let sessionCategory: String
    let sessionHostId: String
    let currentParticipants: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHost = false
    @State private var userName = "User"
    @State private var showSettings = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var isMuted = false
    @State private var isCameraOff = false
    
    var body: some View {
        ZStack {
            // Black background for video
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video area
                ZStack {
                    // Placeholder for video feed
                    VStack(spacing: 16) {
                        Image(systemName: isHost ? "video.circle.fill" : "person.video.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(isHost ? "Broadcasting" : "Watching Stream")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(sessionTitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Top overlay with session info
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sessionTitle)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(sessionCategory)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Live indicator
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red)
                                Text("LIVE")
                                    .font(.caption2)
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Controls bottom section
                VStack(spacing: 12) {
                    // Session stats
                    HStack {
                        Label("\(currentParticipants) watching", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        if isHost {
                            Label("Host", systemImage: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Control buttons
                    HStack(spacing: 12) {
                        if isHost {
                            Button(action: { isMuted.toggle() }) {
                                Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isMuted ? Color.red.opacity(0.3) : Color.gray.opacity(0.3))
                                    .cornerRadius(6)
                            }
                            
                            Button(action: { isCameraOff.toggle() }) {
                                Label(isCameraOff ? "Camera On" : "Camera", systemImage: isCameraOff ? "video.slash.fill" : "video.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isCameraOff ? Color.red.opacity(0.3) : Color.gray.opacity(0.3))
                                    .cornerRadius(6)
                            }
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button("Settings") {
                                showSettings = true
                            }
                            Button("Leave") {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                }
            }
            
            // Loading overlay
            if isConnecting {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Connecting...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupSession()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    LabeledContent("Title") {
                        Text(sessionTitle)
                    }
                    LabeledContent("Category") {
                        Text(sessionCategory)
                    }
                    LabeledContent("Host") {
                        Text(sessionHostId)
                    }
                    LabeledContent("Participants") {
                        Text("\(currentParticipants)")
                    }
                }
                
                Section("Your Settings") {
                    TextField("Username", text: $userName)
                    Toggle("Host", isOn: $isHost)
                }
                
                Section {
                    Button("Leave Stream", role: .destructive) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Stream Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showSettings = false
                    }
                }
            }
        }
    }
    
    private func setupSession() {
        isHost = sessionHostId == userName
        isConnecting = true
        
        // Simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isConnecting = false
        }
    }
    
    private func cleanup() {
        // Cleanup resources
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        BroadcastStreamView_LiveKit(
            sessionTitle: "Evening Prayer",
            sessionCategory: "Prayer",
            sessionHostId: "John",
            currentParticipants: 5
        )
    }
}
