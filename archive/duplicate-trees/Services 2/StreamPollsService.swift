//
//  StreamPollsService.swift
//  Faith Journal
//
//  Polls and Q&A service for live streams
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
struct StreamPoll: Identifiable {
    let id = UUID()
    let question: String
    var options: [PollOption]
    let createdAt: Date
    let duration: TimeInterval
    var isActive: Bool = true
    var totalVotes: Int {
        options.reduce(0) { $0 + $1.voteCount }
    }
    
    struct PollOption: Identifiable {
        let id = UUID()
        let text: String
        var voteCount: Int = 0
        var votedBy: Set<String> = []
    }
}

@available(iOS 17.0, *)
struct StreamQuestion: Identifiable {
    let id = UUID()
    let question: String
    let userId: String
    let userName: String
    let createdAt: Date
    var isPinned: Bool = false
    var isAnswered: Bool = false
    var answer: String?
    var upvotes: Int = 0
    var upvotedBy: Set<String> = []
}

@MainActor
@available(iOS 17.0, *)
class StreamPollsService: ObservableObject {
    static let shared = StreamPollsService()
    
    @Published var activePolls: [StreamPoll] = []
    @Published var questionQueue: [StreamQuestion] = []
    @Published var pinnedQuestions: [StreamQuestion] = []
    
    private init() {}
    
    func createPoll(question: String, options: [String], duration: TimeInterval = 300) -> StreamPoll {
        let pollOptions = options.map { StreamPoll.PollOption(text: $0) }
        let poll = StreamPoll(
            question: question,
            options: pollOptions,
            createdAt: Date(),
            duration: duration
        )
        
        activePolls.append(poll)
        
        // Auto-close poll after duration
        if duration > 0 {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await MainActor.run {
                    if let index = activePolls.firstIndex(where: { $0.id == poll.id }) {
                        activePolls[index].isActive = false
                    }
                }
            }
        }
        
        return poll
    }
    
    func voteOnPoll(pollId: UUID, optionId: UUID, userId: String) {
        guard let pollIndex = activePolls.firstIndex(where: { $0.id == pollId }),
              let optionIndex = activePolls[pollIndex].options.firstIndex(where: { $0.id == optionId }) else {
            return
        }
        
        var poll = activePolls[pollIndex]
        var option = poll.options[optionIndex]
        
        // Remove previous vote if exists
        for (idx, opt) in poll.options.enumerated() {
            if opt.votedBy.contains(userId) {
                poll.options[idx].votedBy.remove(userId)
                poll.options[idx].voteCount = max(0, poll.options[idx].voteCount - 1)
            }
        }
        
        // Add new vote
        option.votedBy.insert(userId)
        option.voteCount += 1
        poll.options[optionIndex] = option
        
        activePolls[pollIndex] = poll
    }
    
    func closePoll(_ pollId: UUID) {
        if let index = activePolls.firstIndex(where: { $0.id == pollId }) {
            activePolls[index].isActive = false
        }
    }
    
    func submitQuestion(question: String, userId: String, userName: String) -> StreamQuestion {
        let streamQuestion = StreamQuestion(
            question: question,
            userId: userId,
            userName: userName,
            createdAt: Date()
        )
        
        questionQueue.append(streamQuestion)
        return streamQuestion
    }
    
    func pinQuestion(_ questionId: UUID) {
        if let index = questionQueue.firstIndex(where: { $0.id == questionId }) {
            var question = questionQueue[index]
            question.isPinned = true
            pinnedQuestions.append(question)
            questionQueue.remove(at: index)
        }
    }
    
    func unpinQuestion(_ questionId: UUID) {
        if let index = pinnedQuestions.firstIndex(where: { $0.id == questionId }) {
            var question = pinnedQuestions[index]
            question.isPinned = false
            questionQueue.append(question)
            pinnedQuestions.remove(at: index)
        }
    }
    
    func answerQuestion(_ questionId: UUID, answer: String) {
        if let index = questionQueue.firstIndex(where: { $0.id == questionId }) {
            questionQueue[index].isAnswered = true
            questionQueue[index].answer = answer
        }
        
        if let index = pinnedQuestions.firstIndex(where: { $0.id == questionId }) {
            pinnedQuestions[index].isAnswered = true
            pinnedQuestions[index].answer = answer
        }
    }
    
    func upvoteQuestion(_ questionId: UUID, userId: String) {
        if let index = questionQueue.firstIndex(where: { $0.id == questionId }) {
            if !questionQueue[index].upvotedBy.contains(userId) {
                questionQueue[index].upvotedBy.insert(userId)
                questionQueue[index].upvotes += 1
            }
        }
        
        if let index = pinnedQuestions.firstIndex(where: { $0.id == questionId }) {
            if !pinnedQuestions[index].upvotedBy.contains(userId) {
                pinnedQuestions[index].upvotedBy.insert(userId)
                pinnedQuestions[index].upvotes += 1
            }
        }
    }
    
    func removeQuestion(_ questionId: UUID) {
        questionQueue.removeAll { $0.id == questionId }
        pinnedQuestions.removeAll { $0.id == questionId }
    }
}

