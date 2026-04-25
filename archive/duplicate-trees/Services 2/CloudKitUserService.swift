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
@available(iOS 17.0, *)
class CloudKitUserService: ObservableObject {
    static let shared: CloudKitUserService = {
        // Only instantiate if running on iOS 17 or later
        if #available(iOS 17.0, *) {
            return CloudKitUserService()
        } else {
            print("⚠️ CloudKitUserService: Not available on iOS < 17. Returning fallback stub.")
            return CloudKitUserService(disableCloudKit: true)
        }
    }()
    
    @Published var currentUserID: String?
    @Published var currentUserName: String?
    @Published var isAuthenticated: Bool = false
    
    private var container: CKContainer?
    private let cloudKitDisabled: Bool

    private init(disableCloudKit: Bool = false) {
        self.cloudKitDisabled = disableCloudKit
        // Set fallback values immediately
        currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        currentUserName = UIDevice.current.name

        // If CloudKit is disabled (by OS or explicit), skip CloudKit setup
        guard !disableCloudKit else {
            container = nil
            print("ℹ️ CloudKitUserService: CloudKit is disabled (OS < 17 or fallback mode)")
            return
        }

        // Try to initialize CloudKit container safely
        // This might fail in simulator or when iCloud is not configured
        #if targetEnvironment(simulator)
        // In simulator, only use CloudKit if explicitly available
        container = nil
        print("ℹ️ CloudKit disabled in simulator - using local identifiers")
        #else
        container = CKContainer.default()
        #endif

        // Check authentication asynchronously after init (only if container available)
        if container != nil {
            Task { @MainActor in
                await checkAuthentication()
            }
        }
    }
    
    func checkAuthentication() async {
        if cloudKitDisabled {
            isAuthenticated = false
            return
        }
        guard let container = container else {
            // No CloudKit available - use device identifiers
            isAuthenticated = false
            return
        }
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
        if cloudKitDisabled {
            currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            currentUserName = UIDevice.current.name
            return
        }
        // Only fetch CloudKit user ID if we're authenticated and have a container
        // This prevents triggering Apple ID sign-in prompt
        guard isAuthenticated, let container = container else {
            // Not authenticated or no container - use device identifier (no sign-in required)
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

