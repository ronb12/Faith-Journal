//
//  WaitingRoomView.swift
//  Faith Journal
//
//  Waiting room UI for sessions before they start
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct WaitingRoomView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var participants: [LiveSessionParticipant]
    @Query var userProfiles: [UserProfile]
    private let userService = LocalUserService.shared
    
    var waitingRoomParticipants: [LiveSessionParticipant] {
        participants.filter { $0.sessionId == session.id && $0.isActive && !session.isActive }
    }
    
    var isHost: Bool {
        session.hostId == userService.userIdentifier
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.platformSystemBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Waiting Room")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(session.title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if let scheduledTime = session.scheduledStartTime {
                            VStack(spacing: 4) {
                                Text("Starts in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                CountdownTimerView(timeUntil: scheduledTime.timeIntervalSince(Date()))
                            }
                            .padding()
                            .background(Color.platformSystemGray6)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    
                    // Participants list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Waiting (\(waitingRoomParticipants.count))")
                                .font(.headline)
                            Spacer()
                            if isHost {
                                Text("\(waitingRoomParticipants.count)/\(session.maxParticipants)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if waitingRoomParticipants.isEmpty {
                            Text("No one in the waiting room yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(waitingRoomParticipants) { participant in
                                        HStack {
                                            Circle()
                                                .fill(Color.purple.opacity(0.3))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text(String(participant.userName.prefix(1)).uppercased())
                                                        .font(.headline)
                                                        .foregroundColor(.purple)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(participant.userName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                if participant.isHost {
                                                    Text("Host")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                } else if participant.isCoHost {
                                                    Text("Co-Host")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if participant.handRaised {
                                                Image(systemName: "hand.raised.fill")
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding()
                                        .background(Color.platformSystemGray6)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Host controls
                    if isHost {
                        VStack(spacing: 12) {
                            Button(action: {
                                // Start session - allow all waiting participants in
                                session.isActive = true
                                try? modelContext.save()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Start Session")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Participant view
                        VStack(spacing: 12) {
                            Text("The host will start the session soon")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                // Leave waiting room
                                if let userParticipant = waitingRoomParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                                    userParticipant.isActive = false
                                    session.currentParticipants = max(0, session.currentParticipants - 1)
                                    try? modelContext.save()
                                }
                                dismiss()
                            }) {
                                Text("Leave Waiting Room")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Waiting Room")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") { dismiss() }
                }
            }
            #endif
        }
    }
}
