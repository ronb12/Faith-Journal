import Foundation

enum BibleVersion: String, CaseIterable, Codable {
    case niv = "NIV"
    case kjv = "KJV"
    case esv = "ESV"
    case nlt = "NLT"
    case nasb = "NASB"
    case web = "WEB"
    case msg = "MSG"
    case amp = "AMP"
    case csb = "CSB"
    
    var fullName: String {
        switch self {
        case .niv: return "New International Version"
        case .kjv: return "King James Version"
        case .esv: return "English Standard Version"
        case .nlt: return "New Living Translation"
        case .nasb: return "New American Standard Bible"
        case .web: return "World English Bible"
        case .msg: return "The Message"
        case .amp: return "Amplified Bible"
        case .csb: return "Christian Standard Bible"
        }
    }
}
