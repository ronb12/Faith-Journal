//
//  StreamFeatureOverlays.swift
//  Faith Journal
//
//  Overlay views for live stream features (reactions, polls, Q&A)
//

import SwiftUI

@available(iOS 17.0, *)
struct ReactionsOverlay: View {
    let reactions: [ReactionData]
    let onReactionSelected: (StreamReaction) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Reaction buttons - horizontally scrollable
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 12) {
                        ForEach(StreamReaction.allCases, id: \.self) { reaction in
                            Button(action: { onReactionSelected(reaction) }) {
                                VStack(spacing: 4) {
                                    Text(reaction.rawValue)
                                        .font(.title2)
                                    Text(reaction.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(width: 70, height: 70)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                )
                .padding(.horizontal, max(16, geometry.safeAreaInsets.leading))
                .padding(.trailing, max(16, geometry.safeAreaInsets.trailing))
                .padding(.bottom, max(16, geometry.safeAreaInsets.bottom))
                
                // Active reactions floating on screen
                ZStack {
                    ForEach(reactions) { reaction in
                        Text(reaction.reaction.rawValue)
                            .font(.system(size: 40))
                            .position(
                                x: reaction.position.x > 0 ? reaction.position.x : CGFloat.random(in: 50...350),
                                y: reaction.position.y > 0 ? reaction.position.y : CGFloat.random(in: 100...600)
                            )
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeOut(duration: 2.0), value: reaction.id)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

@available(iOS 17.0, *)
struct PollsOverlay: View {
    let activePolls: [StreamPoll]
    let onVote: (UUID, UUID) -> Void
    let onCreatePoll: (String, [String]) -> Void
    let onDismiss: () -> Void
    let isHost: Bool
    
    @State private var showingCreatePoll = false
    @State private var pollQuestion = ""
    @State private var pollOptions = ["", ""]
    
    var body: some View {
        VStack {
            HStack {
                Text("Polls")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isHost {
                    Button(action: { showingCreatePoll = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(activePolls.filter { $0.isActive }) { poll in
                        PollCard(poll: poll, onVote: onVote)
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.9))
        .sheet(isPresented: $showingCreatePoll) {
            CreatePollSheet(
                question: $pollQuestion,
                options: $pollOptions,
                onCreate: {
                    onCreatePoll(pollQuestion, pollOptions.filter { !$0.isEmpty })
                    showingCreatePoll = false
                    pollQuestion = ""
                    pollOptions = ["", ""]
                }
            )
        }
    }
}

@available(iOS 17.0, *)
struct PollCard: View {
    let poll: StreamPoll
    let onVote: (UUID, UUID) -> Void
    
    @State private var selectedOption: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(poll.question)
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(poll.options) { option in
                Button(action: {
                    selectedOption = option.id
                    onVote(poll.id, option.id)
                }) {
                    HStack {
                        Text(option.text)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedOption == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Text("\(option.voteCount)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedOption == option.id ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                    )
                }
            }
            
            Text("\(poll.totalVotes) votes")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

@available(iOS 17.0, *)
struct QnAOverlay: View {
    let questions: [StreamQuestion]
    let pinnedQuestions: [StreamQuestion]
    let onSubmitQuestion: (String) -> Void
    let onPinQuestion: (UUID) -> Void
    let onAnswerQuestion: (UUID, String) -> Void
    let onDismiss: () -> Void
    let isHost: Bool
    
    @State private var questionText = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Q&A")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            
            // Question input
            HStack {
                TextField("Ask a question...", text: $questionText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: {
                    if !questionText.isEmpty {
                        onSubmitQuestion(questionText)
                        questionText = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Pinned questions
                    if !pinnedQuestions.isEmpty {
                        Text("Pinned")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        ForEach(pinnedQuestions) { question in
                            StreamQuestionCard(
                                question: question,
                                onPin: { onPinQuestion(question.id) },
                                onAnswer: { answer in onAnswerQuestion(question.id, answer) },
                                isHost: isHost
                            )
                        }
                    }
                    
                    // Regular questions
                    Text("Questions")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal)
                    
                    ForEach(questions.sorted { $0.upvotes > $1.upvotes }) { question in
                        StreamQuestionCard(
                            question: question,
                            onPin: { onPinQuestion(question.id) },
                            onAnswer: { answer in onAnswerQuestion(question.id, answer) },
                            isHost: isHost
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.9))
    }
}

@available(iOS 17.0, *)
struct StreamQuestionCard: View {
    let question: StreamQuestion
    let onPin: () -> Void
    let onAnswer: (String) -> Void
    let isHost: Bool
    
    @State private var answerText = ""
    @State private var showingAnswer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(question.userName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if question.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(question.question)
                .font(.body)
                .foregroundColor(.white)
            
            if let answer = question.answer {
                Text("Answer: \(answer)")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            } else if isHost {
                Button(action: { showingAnswer.toggle() }) {
                    Text("Answer")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if showingAnswer {
                    HStack {
                        TextField("Type answer...", text: $answerText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            onAnswer(answerText)
                            answerText = ""
                            showingAnswer = false
                        }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            HStack {
                Text("\(question.upvotes) upvotes")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if isHost && !question.isPinned {
                    Button(action: onPin) {
                        Image(systemName: "pin")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

@available(iOS 17.0, *)
struct CaptionsOverlay: View {
    let caption: String
    let style: StreamCaptionsService.CaptionStyle
    
    var body: some View {
        VStack {
            if style.position == .top {
                CaptionText(caption: caption, style: style)
                    .padding()
                Spacer()
            } else if style.position == .center {
                Spacer()
                CaptionText(caption: caption, style: style)
                    .padding()
                Spacer()
            } else {
                Spacer()
                CaptionText(caption: caption, style: style)
                    .padding()
            }
        }
    }
}

@available(iOS 17.0, *)
struct CaptionText: View {
    let caption: String
    let style: StreamCaptionsService.CaptionStyle
    
    var body: some View {
        Text(caption)
            .font(.system(size: style.fontSize, weight: .medium))
            .foregroundColor(Color(hex: style.fontColor))
            .padding()
            .background(
                style.showBackground ?
                Color(hex: style.backgroundColor) : Color.clear
            )
            .cornerRadius(8)
            .multilineTextAlignment(.center)
    }
}

@available(iOS 17.0, *)
struct CreatePollSheet: View {
    @Binding var question: String
    @Binding var options: [String]
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: PollField?
    @State private var showingDeleteAlert = false
    @State private var optionToDelete: Int?
    
    enum PollField: Hashable {
        case question
        case option(Int)
    }
    
    private var validOptionsCount: Int {
        options.filter { !$0.isEmpty }.count
    }
    
    private var canCreate: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validOptionsCount >= 2 &&
        validOptionsCount <= 6
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 8)
                        
                        Text("Create Poll")
                            .font(.largeTitle)
                            .font(.body.weight(.bold))
                        
                        Text("Engage your audience with interactive polls")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // Question Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Poll Question")
                                .font(.headline)
                        }
                        
                        TextField("What would you like to ask?", text: $question, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .question ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .focused($focusedField, equals: .question)
                            .lineLimit(3...6)
                        
                        HStack {
                            Spacer()
                            Text("\(question.count)/200")
                                .font(.caption)
                                .foregroundColor(question.count > 200 ? .red : .secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Options Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundColor(.purple)
                            Text("Poll Options")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(validOptionsCount)/6")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                        }
                        
                        ForEach(0..<options.count, id: \.self) { index in
                            HStack(spacing: 12) {
                                // Option number badge
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                
                                // Text field
                                TextField("Option \(index + 1)", text: $options[index])
                                    .textFieldStyle(.plain)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemGray6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                focusedField == .option(index) ? Color.blue : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .focused($focusedField, equals: .option(index))
                                
                                // Delete button (only show if more than 2 options)
                                if options.count > 2 {
                                    Button(action: {
                                        optionToDelete = index
                                        showingDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Add Option Button
                        if options.count < 6 {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    options.append("")
                                    // Focus on the new field after a brief delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        focusedField = .option(options.count - 1)
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Option")
                                }
                                .font(.subheadline)
                                .font(.body.weight(.medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack {
                                Spacer()
                                Text("Maximum 6 options")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Requirements Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Requirements")
                                .font(.subheadline)
                                .font(.body.weight(.semibold))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            RequirementRow(
                                met: !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                text: "Question is required"
                            )
                            RequirementRow(
                                met: validOptionsCount >= 2,
                                text: "At least 2 options required"
                            )
                            RequirementRow(
                                met: validOptionsCount <= 6,
                                text: "Maximum 6 options allowed"
                            )
                        }
                        .padding(.leading, 24)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        onCreate()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create")
                        }
                        .font(.body.weight(.semibold))
                    }
                    .disabled(!canCreate)
                    .foregroundColor(canCreate ? .blue : .gray)
                }
            }
            .alert("Delete Option?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let index = optionToDelete {
                        _ = withAnimation {
                            options.remove(at: index)
                        }
                    }
                    optionToDelete = nil
                }
            } message: {
                Text("This option will be removed from the poll.")
            }
        }
    }
}

@available(iOS 17.0, *)
private struct RequirementRow: View {
    let met: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .gray)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(met ? .primary : .secondary)
        }
    }
}

@available(iOS 17.0, *)
struct AnalyticsSheet: View {
    @ObservedObject var analytics: StreamAnalyticsService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Viewers") {
                    HStack {
                        Text("Current")
                        Spacer()
                        Text("\(analytics.currentViewerCount)")
                    }
                    HStack {
                        Text("Peak")
                        Spacer()
                        Text("\(analytics.peakViewerCount)")
                    }
                    HStack {
                        Text("Average Watch Time")
                        Spacer()
                        Text(formatTime(analytics.averageWatchTime))
                    }
                }
                
                Section("Stream Quality") {
                    HStack {
                        Text("Bitrate")
                        Spacer()
                        Text(String(format: "%.1f Mbps", analytics.bitrate))
                    }
                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Text(String(format: "%.0f fps", analytics.frameRate))
                    }
                    HStack {
                        Text("Resolution")
                        Spacer()
                        Text(analytics.resolution)
                    }
                    HStack {
                        Text("Latency")
                        Spacer()
                        Text(String(format: "%.0f ms", analytics.latency * 1000))
                    }
                }
                
                Section("Engagement") {
                    HStack {
                        Text("Engagement Rate")
                        Spacer()
                        Text(String(format: "%.1f%%", analytics.engagementRate))
                    }
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@available(iOS 17.0, *)
struct HighlightsSheet: View {
    let highlights: [StreamHighlightsService.StreamHighlight]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(highlights) { highlight in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(highlight.title)
                                .font(.headline)
                            Text(formatTime(highlight.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(highlight.shareCount) shares")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Highlights")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@available(iOS 17.0, *)
struct StreamShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

