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
                isAuthenticated = true
                await fetchUserID()
            case .noAccount:
                isAuthenticated = false
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            case .couldNotDetermine:
                isAuthenticated = false
            case .restricted:
                isAuthenticated = false
            case .temporarilyUnavailable:
                isAuthenticated = false
            @unknown default:
                isAuthenticated = false
            }
        } catch {
            // If CloudKit fails, use fallback values
            isAuthenticated = false
            currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            currentUserName = UIDevice.current.name
        }
    }
    
    func fetchUserID() async {
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
            // Fallback to device identifier
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

