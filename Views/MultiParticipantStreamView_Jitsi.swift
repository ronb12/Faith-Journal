//
//  MultiParticipantStreamView_Jitsi.swift
//  Faith Journal
//
//  Conference mode using Jitsi Meet SDK
//  All participants can stream video and audio
//

import SwiftUI

#if canImport(JitsiMeetSDK)
import JitsiMeetSDK
#endif

@available(iOS 17.0, *)
struct MultiParticipantStreamView_Jitsi: View {
    let session: LiveSession
    // Use regular property for singleton, not @StateObject
    private let jitsiService = JitsiService.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Jitsi video view
                #if canImport(JitsiMeetSDK)
                if let jitsiView = jitsiService.getJitsiView() {
                    JitsiMeetViewWrapper(jitsiView: jitsiView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.black
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Joining conference...")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                        )
                }
                #else
                Color.black
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            Text("Jitsi Meet SDK not available")
                                .foregroundColor(.white)
                                .padding(.top)
                            Text("Please add Jitsi Meet SDK package")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    )
                #endif
                
                // Controls
                VStack(spacing: 16) {
                    // Session info and participant count
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(jitsiService.participantCount + 1) participant\(jitsiService.participantCount == 0 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        // Toggle video
                        Button(action: {
                            jitsiService.toggleVideo()
                        }) {
                            Image(systemName: jitsiService.isVideoEnabled ? "video.fill" : "video.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(jitsiService.isVideoEnabled ? Color.blue : Color.gray)
                                .clipShape(Circle())
                        }
                        
                        // Toggle audio
                        Button(action: {
                            jitsiService.toggleAudio()
                        }) {
                            Image(systemName: jitsiService.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(jitsiService.isAudioEnabled ? Color.blue : Color.gray)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Leave button
                        Button(action: {
                            jitsiService.leaveConference()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "phone.down.fill")
                                Text("Leave")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            joinConference()
        }
        .onChange(of: jitsiService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingError = true
            }
        }
    }
    
    private func joinConference() {
        Task {
            do {
                let userId = userService.userIdentifier
                let userName = userService.displayName
                
                // Generate room name from session ID
                let roomName = "faith-journal-\(session.id.uuidString)"
                
                try await jitsiService.joinConference(
                    sessionId: session.id,
                    userId: userId,
                    userName: userName,
                    roomName: roomName
                )
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Jitsi View Wrapper

#if canImport(JitsiMeetSDK)
struct JitsiMeetViewWrapper: UIViewRepresentable {
    let jitsiView: Any
    
    func makeUIView(context: Context) -> UIView {
        guard let view = jitsiView as? UIView else {
            // Fallback to empty view if cast fails
            return UIView()
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}
#endif

