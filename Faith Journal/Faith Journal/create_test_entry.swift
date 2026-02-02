#!/usr/bin/env swift

import Foundation
import CloudKit

// Create a test journal entry in CloudKit
let container = CKContainer(identifier: "iCloud.com.ronellbradley.FaithJournal")
let privateDatabase = container.privateCloudDatabase

let record = CKRecord(recordType: "CD_JournalEntry")
record["id"] = "TEST-ENTRY-001" as CKRecordValue
record["title"] = "Test Journal Entry - CloudKit Verification" as CKRecordValue
record["content"] = "This is a test journal entry created to verify CloudKit sync is working properly. If you can see this entry, CloudKit is functioning correctly!" as CKRecordValue
record["date"] = Date() as CKRecordValue
record["createdAt"] = Date() as CKRecordValue
record["updatedAt"] = Date() as CKRecordValue
record["tags"] = ["test", "cloudkit", "verification"] as CKRecordValue
record["mood"] = "Grateful" as CKRecordValue
record["isPrivate"] = 0 as CKRecordValue

privateDatabase.save(record) { (savedRecord, error) in
    if let error = error {
        print("❌ Error: \(error.localizedDescription)")
        if let ckError = error as? CKError {
            print("   Code: \(ckError.code.rawValue)")
            print("   Domain: \(ckError.domain)")
        }
        exit(1)
    } else {
        print("✅ Successfully created test journal entry!")
        print("   Record ID: \(savedRecord?.recordID.recordName ?? "unknown")")
        print("   Title: \(savedRecord?["title"] ?? "unknown")")
        exit(0)
    }
}

// Keep the script running
RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))


