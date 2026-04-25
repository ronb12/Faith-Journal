//
//  BiblePassage.swift
//  Faith Journal
//
//  Model for a passage of Bible verses
//

import Foundation

public struct BiblePassage: Codable {
    public let reference: String
    public let verses: [BibleVerse]
    public let text: String
}
