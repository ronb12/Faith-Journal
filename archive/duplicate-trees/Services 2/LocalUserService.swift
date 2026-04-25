//
//  LocalUserService.swift
//  Faith Journal
//
//  Local user service to replace CloudKitUserService
//  Uses device identifier and UserProfile for user information
//

import Foundation
import Combine
import UIKit
import SwiftData

@MainActor
@available(iOS 17.0, *)
class LocalUserService: ObservableObject {
    static let shared = LocalUserService()
    
    @Published var currentUserID: String
    @Published var currentUserName: String
    @Published var isAuthenticated: Bool = true // Always true for local service
    
    private init() {
        // Use device identifier as user ID
        currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        currentUserName = UIDevice.current.name
        
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

