//
//  BackgroundSyncService.swift
//  Faith Journal
//
//  Service to automatically check and sync Firebase data in the background
//

import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

#if canImport(BackgroundTasks) && os(iOS)
import BackgroundTasks
#endif

@MainActor
@available(iOS 17.0, *)
class BackgroundSyncService {
    static let shared = BackgroundSyncService()
    
    private let syncTaskIdentifier = "com.ronellbradley.FaithJournal.backgroundSync"
    
    private init() {
        // Don't register in init - do it lazily when needed
        // This prevents crashes if background tasks aren't properly configured
    }
    
    /// Register the background task with the system
    /// Note: Firebase handles sync automatically via listeners, so background tasks are not needed
    func registerBackgroundTask() {
        // Firebase sync works automatically via real-time listeners in FirebaseSyncService
        // Background tasks are not required since Firebase handles everything automatically
        // Skipping registration to prevent crashes - Firebase handles sync automatically
        print("ℹ️ [BACKGROUND SYNC] Background task registration skipped - Firebase handles sync automatically via listeners")
    }
    
    /// Schedule a background sync task
    /// This will be called periodically by iOS to check for pending sync operations
    func scheduleBackgroundSync() {
#if canImport(BackgroundTasks) && os(iOS)
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        
        // Schedule to run periodically (iOS decides the best time)
        // Request earliest start time of 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ [BACKGROUND SYNC] Scheduled background sync task")
        } catch {
            print("❌ [BACKGROUND SYNC] Could not schedule background sync: \(error.localizedDescription)")
        }
#else
        print("ℹ️ [BACKGROUND SYNC] BackgroundTasks not available on this build target")
#endif
    }
    
    /// Cancel any pending background sync tasks
    func cancelBackgroundSync() {
#if canImport(BackgroundTasks) && os(iOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: syncTaskIdentifier)
        print("ℹ️ [BACKGROUND SYNC] Cancelled background sync task")
#else
        print("ℹ️ [BACKGROUND SYNC] BackgroundTasks not available on this build target")
#endif
    }
    
    /// Handle the background sync task when iOS executes it
    #if canImport(BackgroundTasks) && os(iOS)
    private func handleBackgroundSync(task: BGProcessingTask) {
        print("🔄 [BACKGROUND SYNC] Background sync task started")
        
        // Schedule the next background sync
        scheduleBackgroundSync()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            print("⚠️ [BACKGROUND SYNC] Background sync task expired")
        }
        
        // Perform the sync check
        Task {
            let hasPendingSync = await checkForPendingSync()
            
            if hasPendingSync {
                print("🔄 [BACKGROUND SYNC] Pending sync detected, syncing...")
                await performBackgroundSync()
                task.setTaskCompleted(success: true)
                print("✅ [BACKGROUND SYNC] Background sync completed")
            } else {
                print("ℹ️ [BACKGROUND SYNC] No pending sync, task completed")
                task.setTaskCompleted(success: true)
            }
        }
    }
    #endif
    
    /// Check if there are pending Firebase sync operations
    private func checkForPendingSync() async -> Bool {
        // Firebase handles sync automatically via listeners
        // This is a placeholder for future implementation if needed
        return false
    }
    
    /// Perform background sync using Firebase
    private func performBackgroundSync() async {
        // Firebase sync is handled automatically by FirebaseSyncService listeners
        // This method is kept for compatibility but doesn't need to do anything
        print("ℹ️ [BACKGROUND SYNC] Firebase handles sync automatically via listeners")
    }
    
    /// Check for pending sync and sync if needed (can be called from foreground)
    func checkAndSyncIfNeeded(context: ModelContext) async {
        print("🔍 [BACKGROUND SYNC] Checking for pending sync...")
        
        // Firebase sync is handled automatically, but we can trigger a full sync if needed
        await FirebaseSyncService.shared.syncAllData()
        print("✅ [BACKGROUND SYNC] Firebase sync initiated")
    }
    
    /// Enable background app refresh for automatic syncing
    func enableBackgroundRefresh() {
        // Request background refresh capability
        // This is handled by iOS automatically when background modes are enabled
        // We just need to schedule tasks
        scheduleBackgroundSync()
        print("✅ [BACKGROUND SYNC] Background refresh enabled")
    }
}

