//
//  BottomActionBar.swift
//  Faith Journal
//
//  Created for responsive bottom action bar without horizontal scrolling
//

import SwiftUI

@available(iOS 17.0, *)
struct BottomActionBar: View {
    // Button actions
    let onReactions: () -> Void
    let onPolls: () -> Void
    let onQnA: () -> Void
    let onFlipCamera: () -> Void
    let onBackgroundBlur: () -> Void
    let onToggleVideo: () -> Void
    let onToggleAudio: () -> Void
    let onToggleChat: () -> Void
    let onHighlights: () -> Void
    let onShare: () -> Void
    let onAnalytics: () -> Void
    let onStop: () -> Void
    
    // Button states
    let showingReactions: Bool
    let backgroundBlurEnabled: Bool
    let isVideoEnabled: Bool
    let isAudioEnabled: Bool
    let showChatOverlay: Bool
    let unreadMessageCount: Int
    let largerButtons: Bool
    let highContrast: Bool
    
    // Button size constants
    private let buttonSize: CGFloat = 52 // Fixed square tap area (48-56pt range)
    private let spacing: CGFloat = 8
    
    // Define all buttons as an array for easier management
    private var buttons: [ActionButton] {
        [
            ActionButton(
                id: "reactions",
                icon: "heart.fill",
                label: "Reactions",
                color: .pink,
                isActive: showingReactions,
                action: onReactions
            ),
            ActionButton(
                id: "polls",
                icon: "chart.bar.fill",
                label: "Polls",
                color: highContrast ? .black : .white,
                backgroundColor: highContrast ? .white : .white.opacity(0.2),
                action: onPolls
            ),
            ActionButton(
                id: "qna",
                icon: "questionmark.circle.fill",
                label: "Q&A",
                color: highContrast ? .black : .white,
                backgroundColor: highContrast ? .white : .white.opacity(0.2),
                action: onQnA
            ),
            ActionButton(
                id: "flip",
                icon: "camera.rotate.fill",
                label: "Flip Camera",
                color: highContrast ? .black : .white,
                backgroundColor: highContrast ? .white : .white.opacity(0.2),
                action: onFlipCamera
            ),
            ActionButton(
                id: "blur",
                icon: backgroundBlurEnabled ? "camera.filters" : "camera",
                label: backgroundBlurEnabled ? "Background Blur On" : "Background Blur Off",
                color: highContrast ? .black : .white,
                backgroundColor: backgroundBlurEnabled ? (highContrast ? .yellow : .purple) : (highContrast ? .white : .white.opacity(0.2)),
                action: onBackgroundBlur
            ),
            ActionButton(
                id: "video",
                icon: isVideoEnabled ? "video.fill" : "video.slash.fill",
                label: isVideoEnabled ? "Video On" : "Video Off",
                color: highContrast ? .black : .white,
                backgroundColor: isVideoEnabled ? (highContrast ? .green : .blue) : .gray,
                action: onToggleVideo
            ),
            ActionButton(
                id: "audio",
                icon: isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                label: isAudioEnabled ? "Microphone On" : "Microphone Off",
                color: highContrast ? .black : .white,
                backgroundColor: isAudioEnabled ? (highContrast ? .green : .blue) : .gray,
                action: onToggleAudio
            ),
            ActionButton(
                id: "chat",
                icon: showChatOverlay ? "bubble.left.fill" : "bubble.left",
                label: showChatOverlay ? "Chat Visible" : "Chat Hidden",
                color: highContrast ? .black : .white,
                backgroundColor: showChatOverlay ? (highContrast ? .yellow : .purple) : (highContrast ? .white : .white.opacity(0.2)),
                badge: unreadMessageCount > 0 ? unreadMessageCount : nil,
                action: onToggleChat
            ),
            ActionButton(
                id: "highlights",
                icon: "star.fill",
                label: "Highlights",
                color: .yellow,
                backgroundColor: .white.opacity(0.2),
                action: onHighlights
            ),
            ActionButton(
                id: "share",
                icon: "square.and.arrow.up.fill",
                label: "Share Stream",
                color: highContrast ? .black : .white,
                backgroundColor: highContrast ? .white : .white.opacity(0.2),
                action: onShare
            ),
            ActionButton(
                id: "analytics",
                icon: "chart.line.uptrend.xyaxis",
                label: "Analytics",
                color: highContrast ? .black : .white,
                backgroundColor: highContrast ? .white : .white.opacity(0.2),
                action: onAnalytics
            ),
            ActionButton(
                id: "stop",
                icon: "stop.circle.fill",
                label: "Stop Broadcasting",
                color: .white,
                backgroundColor: .red,
                isPrimary: true,
                action: onStop
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Use LazyVGrid for responsive layout (12 buttons - more than 5)
            // 5 columns for optimal button distribution across all iPhone sizes
            let columns = [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ]
            
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(buttons) { button in
                    buttonView(button)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.9), Color.black.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private func buttonView(_ button: ActionButton) -> some View {
        Button(action: button.action) {
            ZStack {
                // Badge overlay for chat button
                if let badge = button.badge {
                    Text("\(badge)")
                        .font(.caption2)
                        .font(.body.weight(.bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: buttonSize/2 - 8, y: -buttonSize/2 + 8)
                }
                
                // Button icon
                Image(systemName: button.icon)
                    .font(button.isPrimary ? .title2 : .title3)
                    .foregroundColor(button.color)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(button.backgroundColor)
                    .clipShape(Circle())
                    .overlay(
                        Group {
                            if button.isActive {
                                Circle()
                                    .stroke(button.color, lineWidth: 2)
                            }
                        }
                    )
            }
        }
        .accessibilityLabel(button.label)
        .accessibilityHint(button.hint ?? "")
    }
}

// MARK: - ActionButton Model

private struct ActionButton: Identifiable {
    let id: String
    let icon: String
    let label: String
    let color: Color
    var backgroundColor: Color = .white.opacity(0.2)
    var isActive: Bool = false
    var isPrimary: Bool = false
    var badge: Int? = nil
    var hint: String? = nil
    let action: () -> Void
}

// MARK: - Preview

@available(iOS 17.0, *)
struct BottomActionBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                BottomActionBar(
                    onReactions: {},
                    onPolls: {},
                    onQnA: {},
                    onFlipCamera: {},
                    onBackgroundBlur: {},
                    onToggleVideo: {},
                    onToggleAudio: {},
                    onToggleChat: {},
                    onHighlights: {},
                    onShare: {},
                    onAnalytics: {},
                    onStop: {},
                    showingReactions: false,
                    backgroundBlurEnabled: false,
                    isVideoEnabled: true,
                    isAudioEnabled: true,
                    showChatOverlay: false,
                    unreadMessageCount: 3,
                    largerButtons: false,
                    highContrast: false
                )
            }
        }
    }
}

