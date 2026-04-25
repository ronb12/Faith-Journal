//
//  YouTubeStyleStreamView.swift
//  Faith Journal
//
//  YouTube-inspired viewer mode UI for live streams
//

import SwiftUI

@available(iOS 17.0, *)
struct YouTubeStyleStreamView: View {
    let session: LiveSession?
    let isHost: Bool
    @Binding var showChatOverlay: Bool
    @Binding var showingReactions: Bool
    @Binding var showingPolls: Bool
    @Binding var showingQnA: Bool
    @Binding var controlsVisible: Bool
    @Binding var theaterMode: Bool
    
    let viewerCount: Int
    let onReaction: () -> Void
    let onToggleChat: () -> Void
    let onToggleTheater: () -> Void
    let onShare: () -> Void
    
    @State private var chatCollapsed = false
    @State private var showFloatingReactions = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent background - video is already rendered behind this overlay
                Color.clear
                    .ignoresSafeArea()
                
                // Top gradient overlay (for controls visibility)
                if controlsVisible {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea()
                }
                
                // Bottom gradient overlay
                if controlsVisible {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)
                }
                
                VStack(spacing: 0) {
                    // Top bar (viewer count, share, theater mode)
                    if controlsVisible {
                        topBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Bottom controls (minimal - just essential)
                    if controlsVisible {
                        bottomControls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Floating action button for reactions (always visible)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingReactionButton
                            .padding(.trailing, 16)
                            .padding(.bottom, theaterMode ? 100 : 80)
                    }
                }
                
                // Chat panel (collapsible, side or bottom) - handled by parent view
                // Chat is shown via LiveStreamChatOverlay in parent
            }
        }
        .allowsHitTesting(true) // Allow taps to pass through to video player
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible.toggle()
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Viewer count
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                Text("\(viewerCount)")
                    .font(.caption)
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
            
            Spacer()
            
            // Share button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            // Theater mode toggle
            Button(action: onToggleTheater) {
                Image(systemName: theaterMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Chat toggle
            Button(action: onToggleChat) {
                VStack(spacing: 4) {
                    Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left")
                        .font(.title3)
                    Text("Chat")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
            
            // Reactions
            Button(action: {
                showingReactions.toggle()
                showFloatingReactions = false
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                    Text("React")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
            
            // Polls
            Button(action: { showingPolls.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                    Text("Polls")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
            
            // Q&A
            Button(action: { showingQnA.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                    Text("Q&A")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Floating Reaction Button
    
    private var floatingReactionButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showFloatingReactions.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: showFloatingReactions ? "xmark" : "heart.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .overlay(
            // Quick reaction buttons
            Group {
                if showFloatingReactions {
                    VStack(spacing: 12) {
                        quickReactionButton(icon: "heart.fill", color: .red, action: { onReaction(); showFloatingReactions = false })
                        quickReactionButton(icon: "hand.thumbsup.fill", color: .blue, action: { onReaction(); showFloatingReactions = false })
                        quickReactionButton(icon: "star.fill", color: .yellow, action: { onReaction(); showFloatingReactions = false })
                        quickReactionButton(icon: "flame.fill", color: .orange, action: { onReaction(); showFloatingReactions = false })
                    }
                    .offset(y: -80)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
    }
    
    private func quickReactionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Chat Panel
    
    private func chatPanel(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Chat header with collapse button
                HStack {
                    Text("Live Chat")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { chatCollapsed.toggle() }) {
                        Image(systemName: chatCollapsed ? "chevron.left" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // Chat content (if not collapsed)
                if !chatCollapsed {
                    // Chat messages will be injected here
                    Color.clear
                        .frame(width: min(geometry.size.width * 0.35, 300))
                        .background(Color.black.opacity(0.7))
                }
            }
            .frame(width: chatCollapsed ? 50 : min(geometry.size.width * 0.35, 300))
            .background(Color.black.opacity(0.8))
            .cornerRadius(12, corners: [.topLeft, .bottomLeft])
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

