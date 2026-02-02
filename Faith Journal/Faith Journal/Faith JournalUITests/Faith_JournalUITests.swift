//
//  Faith_JournalUITests.swift
//  Faith JournalUITests
//
//  Created by Ronell Bradley on 6/29/25.
//

import XCTest

final class Faith_JournalUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    // MARK: - Live Streaming UI Tests
    
    @MainActor
    @available(iOS 17.0, *)
    func testNavigateToLiveSessions() throws {
        // Navigate to More tab
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "More tab should exist")
        moreTab.tap()
        
        // Navigate to Live Sessions
        let liveSessionsButton = app.buttons["Live Sessions"]
        XCTAssertTrue(liveSessionsButton.waitForExistence(timeout: 10), "Live Sessions button should exist")
        liveSessionsButton.tap()
        
        // Verify we're on Live Sessions view
        let liveSessionsTitle = app.navigationBars["Live Sessions"]
        XCTAssertTrue(liveSessionsTitle.waitForExistence(timeout: 10), "Should be on Live Sessions view")
    }
    
    @MainActor
    @available(iOS 17.0, *)
    func testViewLiveSessionsList() throws {
        navigateToLiveSessions()
        
        // Check for session list elements
        let sessionList = app.scrollViews.firstMatch
        XCTAssertTrue(sessionList.waitForExistence(timeout: 10), "Session list should exist")
    }
    
    @MainActor
    @available(iOS 17.0, *)
    func testStartBroadcastStream() throws {
        navigateToLiveSessions()
        
        // Look for start broadcast button
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start' OR label CONTAINS[c] 'Broadcast'")).firstMatch
        if startButton.waitForExistence(timeout: 10) {
            startButton.tap()
            handlePermissions()
            
            // Wait a moment for stream to start
            sleep(2)
            
            // Look for done/end button to close
            let doneButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done' OR label CONTAINS[c] 'End'")).firstMatch
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    @MainActor
    @available(iOS 17.0, *)
    func testStartConferenceStream() throws {
        navigateToLiveSessions()
        
        // Look for conference mode button or picker
        let modePicker = app.segmentedControls.firstMatch
        if modePicker.waitForExistence(timeout: 10) {
            // Select conference mode
            let conferenceSegment = modePicker.buttons["Conference"]
            if conferenceSegment.exists {
                conferenceSegment.tap()
                
                // Then start stream
                let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start'")).firstMatch
                if startButton.exists {
                    startButton.tap()
                    handlePermissions()
                    
                    // Wait for stream to start
                    sleep(2)
                    
                    // Test controls
                    try testStreamControls()
                    
                    // End stream
                    let doneButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done' OR label CONTAINS[c] 'End'")).firstMatch
                    if doneButton.exists {
                        doneButton.tap()
                    }
                }
            }
        }
    }
    
    @MainActor
    @available(iOS 17.0, *)
    private func testStreamControls() throws {
        // Test video toggle
        let videoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'video'")).firstMatch
        if videoButton.exists && videoButton.isEnabled {
            videoButton.tap()
            sleep(1)
        }
        
        // Test audio toggle
        let audioButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'mic' OR label CONTAINS[c] 'audio'")).firstMatch
        if audioButton.exists && audioButton.isEnabled {
            audioButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToLiveSessions() {
        // Navigate to More tab
        let moreTab = app.tabBars.buttons["More"]
        if moreTab.waitForExistence(timeout: 10) {
            moreTab.tap()
        }
        
        // Navigate to Live Sessions
        let liveSessionsButton = app.buttons["Live Sessions"]
        if liveSessionsButton.waitForExistence(timeout: 10) {
            liveSessionsButton.tap()
        }
    }
    
    private func handlePermissions() {
        // Handle camera permission
        let cameraAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'Camera'")).firstMatch
        if cameraAlert.waitForExistence(timeout: 3) {
            let allowButton = cameraAlert.buttons["OK"] ?? cameraAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // Handle microphone permission
        let micAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'Microphone' OR label CONTAINS[c] 'Mic'")).firstMatch
        if micAlert.waitForExistence(timeout: 3) {
            let allowButton = micAlert.buttons["OK"] ?? micAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // Small delay for permissions to process
        sleep(1)
    }
}
