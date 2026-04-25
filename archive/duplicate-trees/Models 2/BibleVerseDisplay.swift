// BibleVerseDisplay.swift
// Faith Journal

import Foundation

public struct BibleVerseDisplay: Identifiable, Hashable, Codable {
    public var id = UUID()
    public let number: Int
    public let text: String
}
