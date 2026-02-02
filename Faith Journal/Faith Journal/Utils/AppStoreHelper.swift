//
//  AppStoreHelper.swift
//  Faith Journal
//
//  Helper for App Store links and installation prompts
//

import Foundation
import UIKit

struct AppStoreHelper {
    // App Store ID from App Store Connect
    // App Information > General Information > Apple ID
    private static let appStoreID = "6746383133"
    
    // Bundle identifier for constructing App Store URLs
    private static let bundleIdentifier = "com.ronellbradley.FaithJournal"
    
    /// Returns the App Store URL for Faith Journal
    /// Direct App Store link using App ID
    static var appStoreURL: String {
        return "https://apps.apple.com/app/id\(appStoreID)"
    }
    
    /// Opens the App Store page for Faith Journal
    static func openAppStore() {
        if let url = URL(string: appStoreURL) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Returns installation instructions text for users without the app
    static func installationInstructions(inviteCode: String) -> String {
        return """
        📱 Don't have the Faith Journal app?
        
        To join this session:
        
        1. Install Faith Journal from the App Store:
        \(appStoreURL)
        
        2. Open the app and sign in
        
        3. Go to Live Sessions → Invitations
        
        4. Tap "Join by Code"
        
        5. Enter this code: \(inviteCode)
        
        Or scan the QR code below after installing the app!
        """
    }
}

