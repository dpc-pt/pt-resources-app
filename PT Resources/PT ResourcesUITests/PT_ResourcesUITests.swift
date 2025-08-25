//
//  PT_ResourcesUITests.swift
//  PT ResourcesUITests
//
//  UI tests for PT Resources app
//

import XCTest

final class PT_ResourcesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Test that the main tabs are present
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        
        // Test talks tab is selected by default and visible
        let talksTab = tabBar.buttons["Talks"]
        XCTAssertTrue(talksTab.exists, "Talks tab should exist")
        
        // Test downloads tab exists
        let downloadsTab = tabBar.buttons["Downloads"]
        XCTAssertTrue(downloadsTab.exists, "Downloads tab should exist")
        
        // Test settings tab exists
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    }
    
    @MainActor
    func testTalksListNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Should be on talks tab by default
        let talksTab = app.tabBars.buttons["Talks"]
        XCTAssertTrue(talksTab.isSelected, "Talks tab should be selected by default")
        
        // Check for talks list elements (using mock data)
        let searchField = app.textFields["Search talks..."]
        XCTAssertTrue(searchField.exists, "Search field should be present")
        
        // Test search functionality
        searchField.tap()
        searchField.typeText("gospel")
        
        // Look for filter and sort buttons
        let filterButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Filter'")).firstMatch
        XCTAssertTrue(filterButton.exists, "Filter button should exist")
        
        // Test filter sheet
        filterButton.tap()
        
        // Should show filter sheet
        let filterSheet = app.navigationBars["Filters"]
        XCTAssertTrue(filterSheet.waitForExistence(timeout: 2), "Filter sheet should appear")
        
        // Close filter sheet
        let applyButton = app.buttons["Apply"]
        if applyButton.exists {
            applyButton.tap()
        }
    }
    
    @MainActor 
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        let tabBar = app.tabBars.firstMatch
        
        // Test navigation to Downloads
        let downloadsTab = tabBar.buttons["Downloads"]
        downloadsTab.tap()
        
        // Should show downloads view
        let downloadsTitle = app.navigationBars["Downloads"]
        XCTAssertTrue(downloadsTitle.waitForExistence(timeout: 2), "Downloads navigation title should appear")
        
        // Test navigation to Settings
        let settingsTab = tabBar.buttons["Settings"]
        settingsTab.tap()
        
        // Should show settings view
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2), "Settings navigation title should appear")
        
        // Test navigation back to Talks
        let talksTab = tabBar.buttons["Talks"]
        talksTab.tap()
        
        // Should be back on talks view with search field
        let searchField = app.textFields["Search talks..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Search field should be visible on talks tab")
    }
    
    @MainActor
    func testSettingsView() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Check for settings sections
        let playbackSection = app.staticTexts["Playback"]
        XCTAssertTrue(playbackSection.waitForExistence(timeout: 2), "Playback section should exist")
        
        let storageSection = app.staticTexts["Storage"]
        XCTAssertTrue(storageSection.exists, "Storage section should exist")
        
        let aboutSection = app.staticTexts["About"]
        XCTAssertTrue(aboutSection.exists, "About section should exist")
        
        // Test that version is displayed
        let versionText = app.staticTexts["1.0.0"]
        XCTAssertTrue(versionText.exists, "Version should be displayed")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application with mock data
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
