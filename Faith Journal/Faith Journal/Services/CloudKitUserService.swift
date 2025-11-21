//
//  CloudKitUserService.swift
//  Faith Journal
//
//  Multi-user support for Live Sessions
//

import Foundation
import CloudKit
import Combine
import UIKit

@MainActor
class CloudKitUserService: ObservableObject {
    static let shared = CloudKitUserService()
    
    @Published var currentUserID: String?
    @Published var currentUserName: String?
    @Published var isAuthenticated: Bool = false
    
    private let container: CKContainer
    
    private init() {
        // Use default container which matches bundle identifier
        // Or specify: CKContainer(identifier: "iCloud.com.ronellbradley.FaithJournal")
        container = CKContainer.default()
        // Set fallback values immediately
        currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        currentUserName = UIDevice.current.name
        
        // Check authentication asynchronously after init
        Task { @MainActor in
            await checkAuthentication()
        }
    }
    
    func checkAuthentication() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                // Only fetch CloudKit user ID if account is available
                // This prevents triggering Apple ID sign-in prompt
                isAuthenticated = true
                await fetchUserID()
            case .noAccount:
                // No iCloud account - app works fine without it
                // Use device identifier instead (no sign-in required)
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                currentUserName = UIDevice.current.name
            case .couldNotDetermine:
                // Can't determine status - use device identifier (no sign-in required)
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                currentUserName = UIDevice.current.name
            case .restricted:
                // Restricted - use device identifier (no sign-in required)
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                currentUserName = UIDevice.current.name
            case .temporarilyUnavailable:
                // Temporarily unavailable - use device identifier (no sign-in required)
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                currentUserName = UIDevice.current.name
            @unknown default:
                // Unknown status - use device identifier (no sign-in required)
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                currentUserName = UIDevice.current.name
            }
        } catch {
            // If CloudKit fails, use fallback values (no sign-in required)
            isAuthenticated = false
            currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            currentUserName = UIDevice.current.name
        }
    }
    
    func fetchUserID() async {
        // Only fetch CloudKit user ID if we're authenticated
        // This prevents triggering Apple ID sign-in prompt
        guard isAuthenticated else {
            // Not authenticated - use device identifier (no sign-in required)
            currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            currentUserName = UIDevice.current.name
            return
        }
        
        do {
            let recordID = try await container.userRecordID()
            // Use CloudKit record ID as unique user identifier
            currentUserID = recordID.recordName
            
            // Try to fetch user record for name
            do {
                let record = try await container.publicCloudDatabase.record(for: recordID)
                // Try to get name from user record
                if let firstName = record["firstName"] as? String,
                   let lastName = record["lastName"] as? String {
                    currentUserName = "\(firstName) \(lastName)"
                } else if let email = record["emailAddress"] as? String {
                    currentUserName = email.components(separatedBy: "@").first ?? "User"
                } else {
                    currentUserName = "User \(String(recordID.recordName.prefix(8)))"
                }
            } catch {
                // Fallback to device name if CloudKit unavailable
                currentUserName = UIDevice.current.name
            }
        } catch {
            // Fallback to device identifier (no sign-in required)
            currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            currentUserName = UIDevice.current.name
        }
    }
    
    var userIdentifier: String {
        // Always return a valid identifier - never nil
        if let id = currentUserID, !id.isEmpty {
            return id
        }
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    var displayName: String {
        // Always return a valid name - never nil
        if let name = currentUserName, !name.isEmpty {
            return name
        }
        return UIDevice.current.name
    }
}

