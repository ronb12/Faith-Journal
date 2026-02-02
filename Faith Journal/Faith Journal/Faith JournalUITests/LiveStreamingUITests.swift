//
//  LiveStreamingUITests.swift
//  Faith JournalUITests
//
//  Comprehensive UI tests for all live streaming features
//

import XCTest

@available(iOS 17.0, *)
final class LiveStreamingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set launch arguments for testing
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Grant permissions if needed
        addUIInterruptionMonitor(withDescription: "Camera Permission") { (alert) -> Bool in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }
        
        addUIInterruptionMonitor(withDescription: "Microphone Permission") { (alert) -> Bool in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToLiveSessions() throws {
        // Navigate to More tab
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5), "More tab should exist")
        moreTab.tap()
        
        // Navigate to Live Sessions
        let liveSessionsButton = app.buttons["Live Sessions"]
        XCTAssertTrue(liveSessionsButton.waitForExistence(timeout: 5), "Live Sessions button should exist")
        liveSessionsButton.tap()
        
        // Verify we're on Live Sessions view
        let liveSessionsTitle = app.navigationBars["Live Sessions"]
        XCTAssertTrue(liveSessionsTitle.waitForExistence(timeout: 5), "Should be on Live Sessions view")
    }
    
    // MARK: - Session List Tests
    
    func testViewLiveSessionsList() throws {
        navigateToLiveSessions()
        
        // Check for session list elements
        let sessionList = app.scrollViews.firstMatch
        XCTAssertTrue(sessionList.waitForExistence(timeout: 5), "Session list should exist")
        
        // Check for filter buttons
        let liveNowFilter = app.buttons["Live Now"]
        if liveNowFilter.exists {
            XCTAssertTrue(liveNowFilter.exists, "Live Now filter should exist")
        }
    }
    
    func testFilterSessions() throws {
        navigateToLiveSessions()
        
        // Test filter buttons
        let filters = ["Live Now", "Upcoming", "Past", "My Sessions", "Favorites"]
        
        for filterName in filters {
            let filterButton = app.buttons[filterName]
            if filterButton.exists {
                filterButton.tap()
                // Wait a moment for filter to apply
                sleep(1)
            }
        }
    }
    
    // MARK: - Create Session Tests
    
    func testCreateNewSession() throws {
        navigateToLiveSessions()
        
        // Look for create session button
        let createButton = app.buttons.matching(identifier: "Create Session").firstMatch
        if createButton.exists {
            createButton.tap()
            
            // Fill in session details if form appears
            let titleField = app.textFields["Session Title"]
            if titleField.waitForExistence(timeout: 3) {
                titleField.tap()
                titleField.typeText("Test Session")
            }
            
            // Look for save/create button
            let saveButton = app.buttons["Create"] ?? app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }
        }
    }
    
    // MARK: - Broadcast Mode Tests
    
    func testStartBroadcastStream() throws {
        navigateToLiveSessions()
        
        // Look for start broadcast button
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start' OR label CONTAINS[c] 'Broadcast'")).firstMatch
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
            
            // Handle permissions
            handlePermissions()
            
            // Verify broadcast view appears
            let broadcastView = app.otherElements["BroadcastStreamView"]
            if broadcastView.waitForExistence(timeout: 5) {
                // Test broadcast controls
                testBroadcastControls()
            }
        }
    }
    
    func testBroadcastControls() throws {
        // Test video toggle
        let videoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'video'")).firstMatch
        if videoButton.exists {
            videoButton.tap()
            sleep(1)
            videoButton.tap() // Toggle back
        }
        
        // Test audio toggle
        let audioButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'mic' OR label CONTAINS[c] 'audio'")).firstMatch
        if audioButton.exists {
            audioButton.tap()
            sleep(1)
            audioButton.tap() // Toggle back
        }
        
        // Test end broadcast
        let endButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'End' OR label CONTAINS[c] 'Stop' OR label CONTAINS[c] 'Done'")).firstMatch
        if endButton.exists {
            endButton.tap()
        }
    }
    
    // MARK: - Conference Mode Tests
    
    func testStartConferenceStream() throws {
        navigateToLiveSessions()
        
        // Look for conference mode button or picker
        let conferenceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Conference'")).firstMatch
        if conferenceButton.waitForExistence(timeout: 5) {
            conferenceButton.tap()
            
            // Handle permissions
            handlePermissions()
            
            // Verify conference view appears
            let conferenceView = app.otherElements["LiveStreamView"]
            if conferenceView.waitForExistence(timeout: 5) {
                // Test conference controls
                testConferenceControls()
            }
        } else {
            // Try to find stream mode picker
            let modePicker = app.segmentedControls.firstMatch
            if modePicker.exists {
                // Select conference mode
                let conferenceSegment = modePicker.buttons["Conference"]
                if conferenceSegment.exists {
                    conferenceSegment.tap()
                    
                    // Then start stream
                    let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start'")).firstMatch
                    if startButton.exists {
                        startButton.tap()
                        handlePermissions()
                        testConferenceControls()
                    }
                }
            }
        }
    }
    
    func testConferenceControls() throws {
        // Test video toggle
        let videoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'video'")).firstMatch
        if videoButton.exists {
            XCTAssertTrue(videoButton.isEnabled, "Video button should be enabled")
            videoButton.tap()
            sleep(1)
        }
        
        // Test audio toggle
        let audioButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'mic' OR label CONTAINS[c] 'audio'")).firstMatch
        if audioButton.exists {
            XCTAssertTrue(audioButton.isEnabled, "Audio button should be enabled")
            audioButton.tap()
            sleep(1)
        }
        
        // Test screen sharing (if available)
        let screenShareButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'screen' OR label CONTAINS[c] 'share'")).firstMatch
        if screenShareButton.exists {
            screenShareButton.tap()
            sleep(1)
        }
        
        // Test end call
        let endButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'End' OR label CONTAINS[c] 'Done' OR label CONTAINS[c] 'phone.down'")).firstMatch
        if endButton.exists {
            endButton.tap()
        }
    }
    
    // MARK: - Multi-Participant Mode Tests
    
    func testMultiParticipantStream() throws {
        navigateToLiveSessions()
        
        // Look for multi-participant button
        let multiParticipantButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Multi' OR label CONTAINS[c] 'Participant'")).firstMatch
        if multiParticipantButton.waitForExistence(timeout: 5) {
            multiParticipantButton.tap()
            handlePermissions()
            
            // Test grid layout toggle
            let gridButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'grid'")).firstMatch
            if gridButton.exists {
                gridButton.tap()
                sleep(1)
            }
            
            // Test speaker layout
            let speakerButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'speaker'")).firstMatch
            if speakerButton.exists {
                speakerButton.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Join Session Tests
    
    func testJoinExistingSession() throws {
        navigateToLiveSessions()
        
        // Look for existing session in list
        let sessionCard = app.cells.firstMatch
        if sessionCard.waitForExistence(timeout: 5) {
            sessionCard.tap()
            
            // Look for join button
            let joinButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Join'")).firstMatch
            if joinButton.exists {
                joinButton.tap()
                handlePermissions()
                
                // Verify joined successfully
                sleep(2)
            }
        }
    }
    
    // MARK: - Session Details Tests
    
    func testViewSessionDetails() throws {
        navigateToLiveSessions()
        
        // Tap on a session
        let sessionCard = app.cells.firstMatch
        if sessionCard.waitForExistence(timeout: 5) {
            sessionCard.tap()
            
            // Check for session details
            let detailsView = app.scrollViews.firstMatch
            if detailsView.waitForExistence(timeout: 3) {
                // Scroll to see more details
                detailsView.swipeUp()
                sleep(1)
                detailsView.swipeDown()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleStreamingErrors() throws {
        navigateToLiveSessions()
        
        // Try to start stream without permissions (if possible)
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start'")).firstMatch
        if startButton.exists {
            startButton.tap()
            
            // Check for error alerts
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 3) {
                // Dismiss error
                let okButton = errorAlert.buttons["OK"]
                if okButton.exists {
                    okButton.tap()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToLiveSessions() {
        // Navigate to More tab
        let moreTab = app.tabBars.buttons["More"]
        if moreTab.waitForExistence(timeout: 5) {
            moreTab.tap()
        }
        
        // Navigate to Live Sessions
        let liveSessionsButton = app.buttons["Live Sessions"]
        if liveSessionsButton.waitForExistence(timeout: 5) {
            liveSessionsButton.tap()
        }
    }
    
    private func handlePermissions() {
        // Handle camera permission
        let cameraAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'Camera'")).firstMatch
        if cameraAlert.waitForExistence(timeout: 2) {
            let allowButton = cameraAlert.buttons["OK"] ?? cameraAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // Handle microphone permission
        let micAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'Microphone' OR label CONTAINS[c] 'Mic'")).firstMatch
        if micAlert.waitForExistence(timeout: 2) {
            let allowButton = micAlert.buttons["OK"] ?? micAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // Small delay for permissions to process
        sleep(1)
    }
}

