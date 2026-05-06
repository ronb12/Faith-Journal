//
//  LiveStreamOverlay.swift
//  Faith Journal
//
//  Live stream overlay: controls, chat bubbles, reactions, and bottom bar.
//  Rendered on top of the actual video surface by the parent view.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Design Tokens

private enum YT {
    static let bg        = Color(red: 0.059, green: 0.059, blue: 0.059) // #0F0F0F
    static let surface   = Color(red: 0.129, green: 0.129, blue: 0.129) // #212121
    static let live      = Color(red: 1.0,   green: 0.0,   blue: 0.0)   // #FF0000
    static let text      = Color.white
    static let subtext   = Color(white: 0.65)
    static let scrim     = Color.black.opacity(0.55)

    // Rotating username colours for chat bubbles
    static let nameColors: [Color] = [
        Color(red: 0.12, green: 0.71, blue: 0.96),
        Color(red: 0.30, green: 0.85, blue: 0.56),
        Color(red: 0.96, green: 0.71, blue: 0.12),
        Color(red: 0.96, green: 0.45, blue: 0.12),
        Color(red: 0.71, green: 0.40, blue: 0.96),
        Color(red: 0.96, green: 0.26, blue: 0.45),
    ]

    static let pad: CGFloat       = 16
    static let padSm: CGFloat     = 8
    static let scrimH: CGFloat    = 130
    static let pipRatio: CGFloat  = 9 / 16
}

// MARK: - Models

struct LiveChatMessage: Identifiable {
    let id       = UUID()
    let username : String
    let text     : String
    let isSuperChat    : Bool
    let superChatAmount: String?
    let timestamp: Date = Date()

    var colorIndex: Int { abs(username.hashValue) % YT.nameColors.count }
}

private struct FloatingReaction: Identifiable {
    let id    = UUID()
    let emoji : String
    let xFrac : CGFloat          // 0…1 fraction of container width
    var rise  : CGFloat = 0
    var opacity: Double = 1
}

// MARK: - Main View

@available(iOS 17.0, macOS 14.0, *)
struct LiveStreamOverlay: View {

    // Passed in from parent
    let session            : LiveSession?
    let isHost             : Bool
    @Binding var showChatOverlay  : Bool
    @Binding var showingReactions : Bool
    @Binding var showingPolls     : Bool
    @Binding var showingQnA       : Bool
    @Binding var controlsVisible  : Bool
    @Binding var theaterMode      : Bool
    @Binding var chatMessages     : [LiveChatMessage]

    let viewerCount     : Int
    let onReaction      : () -> Void
    let onToggleChat    : () -> Void
    let onToggleTheater : () -> Void
    let onShare         : () -> Void

    // Internal state
    @State private var floatingReactions: [FloatingReaction] = []
    @State private var showEmojiPicker  : Bool = false
    @State private var isLiked          : Bool = false
    @State private var liveSeconds      : Int  = 0
    @State private var autoHideTask     : Task<Void, Never>? = nil
    @State private var timerTask        : Task<Void, Never>? = nil

    private let quickEmojis = ["❤️", "🙏", "👍", "🔥", "😂", "🕊️"]
    private let moreEmojis  = ["🙌", "✝️", "📖", "🙇", "💒", "🌟",
                                "💫", "✨", "🌈", "🎶", "🎉", "😮"]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.clear.ignoresSafeArea()

                scrimLayer(geo: geo)

                VStack(spacing: 0) {
                    if controlsVisible {
                        topBar
                            .padding(.top, geo.safeAreaInsets.top + YT.padSm)
                            .padding(.horizontal, YT.pad)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    if showChatOverlay {
                        chatStack(geo: geo)
                    }

                    bottomBar(geo: geo)
                }
                .animation(.easeInOut(duration: 0.22), value: controlsVisible)
                .animation(.easeInOut(duration: 0.22), value: showChatOverlay)

                floatingReactionLayer(geo: geo)

                if showEmojiPicker {
                    emojiPickerSheet(geo: geo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showEmojiPicker)
            .contentShape(Rectangle())
            .onTapGesture {
                if showEmojiPicker {
                    withAnimation { showEmojiPicker = false }
                } else {
                    toggleControls()
                }
            }
            .onAppear {
                startLiveTimer()
                scheduleAutoHide()
            }
            .onDisappear {
                timerTask?.cancel()
                autoHideTask?.cancel()
            }
        }
    }

    // MARK: - Gradient scrims

    @ViewBuilder
    private func scrimLayer(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [YT.scrim, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: YT.scrimH + geo.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            Spacer()

            LinearGradient(colors: [.clear, YT.scrim], startPoint: .top, endPoint: .bottom)
                .frame(height: YT.scrimH + geo.safeAreaInsets.bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // LIVE badge + host timer
            VStack(alignment: .leading, spacing: 3) {
                liveBadge
                if isHost {
                    Text(formattedTimer)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(YT.subtext)
                }
            }

            Spacer()

            // Viewer count pill
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.caption2)
                Text(viewerCount.formatted(.number.notation(.compactName)))
                    .font(.caption.weight(.medium)).monospacedDigit()
            }
            .foregroundStyle(YT.text)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(YT.scrim)
            .clipShape(Capsule())
            .accessibilityLabel("\(viewerCount) viewers")

            // Share
            circleButton(icon: "square.and.arrow.up", label: "Share", action: onShare)

            // More menu
            Menu {
                Button("Theater mode", action: onToggleTheater)
                if isHost {
                    Divider()
                    Button(role: .destructive) { } label: {
                        Label("End stream", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.body.weight(.medium))
                    .foregroundStyle(YT.text)
                    .frame(width: 44, height: 44)
                    .background(YT.scrim)
                    .clipShape(Circle())
            }
            .accessibilityLabel("More options")
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(YT.text).frame(width: 7, height: 7)
            Text("LIVE").font(.caption.weight(.bold)).foregroundStyle(YT.text)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(YT.live)
        .clipShape(Capsule())
        .accessibilityLabel("Live")
    }

    // MARK: - Floating chat messages

    @ViewBuilder
    private func chatStack(geo: GeometryProxy) -> some View {
        let maxW = min(geo.size.width * 0.62, 300)
        VStack(alignment: .leading, spacing: 5) {
            ForEach(chatMessages.suffix(5)) { msg in
                chatBubble(msg)
            }
        }
        .frame(maxWidth: maxW, alignment: .leading)
        .padding(.horizontal, YT.pad)
        .padding(.bottom, 6)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func chatBubble(_ msg: LiveChatMessage) -> some View {
        if msg.isSuperChat, let amount = msg.superChatAmount {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption2).foregroundStyle(.yellow)
                    Text("\(msg.username) · \(amount)")
                        .font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                }
                Text(msg.text).font(.caption).foregroundStyle(YT.text)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(red: 0.18, green: 0.10, blue: 0))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            (
                Text(msg.username + "  ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(YT.nameColors[msg.colorIndex])
                + Text(msg.text)
                    .font(.caption)
                    .foregroundStyle(YT.text)
            )
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(YT.scrim)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Quick emoji strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(quickEmojis, id: \.self) { emoji in
                        emojiChip(emoji: emoji)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showEmojiPicker.toggle()
                        }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.title3).foregroundStyle(YT.text)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(showEmojiPicker ? YT.live.opacity(0.35) : YT.scrim)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("More reactions")
                }
                .padding(.horizontal, YT.pad)
            }
            .padding(.vertical, YT.padSm)

            Divider().overlay(Color.white.opacity(0.08))

            // Chat input row + like/share
            HStack(spacing: 10) {
                // Chat input (opens full chat sheet via onToggleChat)
                Button(action: onToggleChat) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left")
                            .font(.subheadline).foregroundStyle(YT.subtext)
                        Text("Say something…")
                            .font(.subheadline).foregroundStyle(YT.subtext)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(YT.surface)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Open live chat")

                // Like
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        isLiked.toggle()
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(isLiked ? YT.live : YT.text)
                        .scaleEffect(isLiked ? 1.15 : 1.0)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isLiked ? "Unlike" : "Like")

                // Share
                Button(action: onShare) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(YT.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share stream")
            }
            .padding(.horizontal, YT.pad)
            .padding(.vertical, 10)
            .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 0 : YT.padSm)
            .background(YT.bg.opacity(0.92))
        }
    }

    private func emojiChip(emoji: String) -> some View {
        Button {
            sendFloatingReaction(emoji: emoji)
            onReaction()
        } label: {
            Text(emoji).font(.title3)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(YT.scrim)
                .clipShape(Capsule())
        }
        .accessibilityLabel("React \(emoji)")
    }

    // MARK: - Emoji picker sheet

    @ViewBuilder
    private func emojiPickerSheet(geo: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(YT.subtext.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 6),
                spacing: 14
            ) {
                ForEach(quickEmojis + moreEmojis, id: \.self) { emoji in
                    Button {
                        sendFloatingReaction(emoji: emoji)
                        onReaction()
                        withAnimation { showEmojiPicker = false }
                    } label: {
                        Text(emoji).font(.largeTitle)
                    }
                    .accessibilityLabel("React \(emoji)")
                }
            }
            .padding(.horizontal, YT.pad)
            .padding(.bottom, geo.safeAreaInsets.bottom + YT.pad)
        }
        .background(YT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
        .padding(.horizontal, 0)
    }

    // MARK: - Floating reactions

    @ViewBuilder
    private func floatingReactionLayer(geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(floatingReactions) { r in
                Text(r.emoji)
                    .font(.system(size: 30))
                    .offset(
                        x: geo.size.width * 0.72 + geo.size.width * 0.12 * r.xFrac,
                        y: r.rise
                    )
                    .opacity(r.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    // MARK: - Shared button style

    private func circleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(YT.text)
                .frame(width: 44, height: 44)
                .background(YT.scrim)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Logic

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible { scheduleAutoHide() }
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = false }
            }
        }
    }

    private func sendFloatingReaction(emoji: String) {
        let r = FloatingReaction(emoji: emoji, xFrac: CGFloat.random(in: 0...1))
        floatingReactions.append(r)
        withAnimation(.easeOut(duration: 2.2)) {
            if let i = floatingReactions.firstIndex(where: { $0.id == r.id }) {
                floatingReactions[i].rise    = -260
                floatingReactions[i].opacity = 0
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run { floatingReactions.removeAll { $0.id == r.id } }
        }
    }

    private func startLiveTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { liveSeconds += 1 }
            }
        }
    }

    private var formattedTimer: String {
        let h = liveSeconds / 3600, m = liveSeconds / 60 % 60, s = liveSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

}

// MARK: - Corner-radius shape (kept for callers that still need it)

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let r   = min(radius, rect.width / 2, rect.height / 2)
        var p   = Path()
        let tl  = corners.contains(.topLeft)
        let tr  = corners.contains(.topRight)
        let bl  = corners.contains(.bottomLeft)
        let br  = corners.contains(.bottomRight)

        p.move(to: CGPoint(x: rect.minX + (tl ? r : 0), y: rect.minY))

        if tr { p.addLine(to: .init(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: .init(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        else { p.addLine(to: .init(x: rect.maxX, y: rect.minY)) }

        if br { p.addLine(to: .init(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: .init(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        else { p.addLine(to: .init(x: rect.maxX, y: rect.maxY)) }

        if bl { p.addLine(to: .init(x: rect.minX + r, y: rect.maxY))
            p.addArc(center: .init(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        else { p.addLine(to: .init(x: rect.minX, y: rect.maxY)) }

        if tl { p.addLine(to: .init(x: rect.minX, y: rect.minY + r))
            p.addArc(center: .init(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        else { p.addLine(to: .init(x: rect.minX, y: rect.minY)) }

        p.closeSubpath()
        return p
    }
}
