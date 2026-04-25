//
//  LocalUserService.swift
//  Faith Journal
//
//  Local user service to replace CloudKitUserService
//  Uses device identifier and UserProfile for user information
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif
import SwiftData

@MainActor
@available(iOS 17.0, macOS 14.0, *)
class LocalUserService: ObservableObject {
    static let shared = LocalUserService()
    
    @Published var currentUserID: String
    @Published var currentUserName: String
    @Published var isAuthenticated: Bool = true // Always true for local service
    
    private init() {
        #if os(iOS)
        currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        currentUserName = UIDevice.current.name
        #else
        currentUserID = ProcessInfo.processInfo.hostName.hashValue.magnitude.description + UUID().uuidString.prefix(8).description
        currentUserName = ProcessInfo.processInfo.hostName
        #endif
        
        print("ℹ️ LocalUserService: Initialized with device ID: \(currentUserID)")
    }
    
    /// Update user name from UserProfile
    func updateFromUserProfile(_ profile: UserProfile?) {
        if let name = profile?.name, !name.isEmpty {
            currentUserName = name
        }
    }
    
    /// Get display name (prioritizes UserProfile name)
    func getDisplayName(userProfile: UserProfile?) -> String {
        if let name = userProfile?.name, !name.isEmpty {
            return name
        }
        return currentUserName
    }
    
    /// Prefer ProfileManager and UserProfile name; never return device name (returns "Participant" when only device name is available). Use for live session and chat.
    func getProfileDisplayName(userProfile: UserProfile?) -> String {
        let pm = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pm.isEmpty && !isDeviceName(pm) { return pm }
        let name = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && !isDeviceName(name) { return name }
        let raw = getDisplayName(userProfile: userProfile)
        return isDeviceName(raw) ? "Participant" : raw
    }
    
    private func isDeviceName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if t.contains("iPhone") || t.contains("iPad") || t.contains("iPod") { return true }
        #if os(iOS)
        if t == UIDevice.current.name { return true }
        #else
        if t == ProcessInfo.processInfo.hostName { return true }
        #endif
        return false
    }
    
    /// Compatibility properties for CloudKitUserService migration
    var userIdentifier: String {
        return currentUserID
    }
    
    /// Display name - returns current user name
    /// Note: For best results, use getDisplayName(userProfile:) when UserProfile is available
    var displayName: String {
        return currentUserName
    }
    
    /// Check authentication (always true for local service, kept for compatibility)
    func checkAuthentication() async {
        // LocalUserService is always authenticated
        isAuthenticated = true
        print("ℹ️ LocalUserService: Authentication check - always authenticated")
    }
}

