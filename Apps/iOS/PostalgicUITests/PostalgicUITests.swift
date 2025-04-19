//
//  PostalgicUITests.swift
//  PostalgicUITests
//
//  Created by Brad Root on 4/19/25.
//

import XCTest

final class PostalgicUITests: XCTestCase {
    
    let app = XCUIApplication()

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // Reset the app state before each test
        app.launchArguments = ["-UITesting", "-DataReset"]
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateAndViewBlog() throws {
        // Launch the app
        app.launch()
        
        // Verify we're on the Blogs screen
        XCTAssertTrue(app.navigationBars["Blogs"].exists)
        
        // Initially, there should be no blogs
        XCTAssertEqual(app.cells.count, 0)
        
        // Tap the Add Blog button
        app.buttons["Add Blog"].tap()
        
        // Verify the sheet is shown with title "New Blog"
        XCTAssertTrue(app.navigationBars["New Blog"].exists)
        
        // Fill in the blog details
        let nameTextField = app.textFields["Name"]
        XCTAssertTrue(nameTextField.exists)
        nameTextField.tap()
        nameTextField.typeText("Test Blog")
        
        let urlTextField = app.textFields["URL"]
        XCTAssertTrue(urlTextField.exists)
        urlTextField.tap()
        urlTextField.typeText("https://example.com")
        
        // Save the blog
        app.buttons["Save"].tap()
        
        // Verify we're back on the Blogs screen and the blog is listed
        XCTAssertTrue(app.navigationBars["Blogs"].exists)
        XCTAssertEqual(app.cells.count, 1)
        
        // Verify the blog name and URL are displayed
        XCTAssertTrue(app.staticTexts["Test Blog"].exists)
        XCTAssertTrue(app.staticTexts["https://example.com"].exists)
    }
    
    func testCreateAndViewPost() throws {
        // First create a blog
        try testCreateAndViewBlog()
        
        // Tap on the blog to view its details
        let app = self.app
        app.cells.element(boundBy: 0).tap()
        
        // Verify we're on the blog detail screen
        XCTAssertTrue(app.navigationBars["Test Blog"].exists)
        
        // Initially, there should be no posts
        XCTAssertEqual(app.cells.count, 0)
        
        // Tap the Add Post button
        app.buttons["Add Post"].tap()
        
        // Verify the sheet is shown with title "New Post"
        XCTAssertTrue(app.navigationBars["New Post"].exists)
        
        // Fill in the post details
        let titleTextField = app.textFields["Title (optional)"]
        XCTAssertTrue(titleTextField.exists)
        titleTextField.tap()
        titleTextField.typeText("Test Post Title")
        
        let linkTextField = app.textFields["Primary Link (optional)"]
        XCTAssertTrue(linkTextField.exists)
        linkTextField.tap()
        linkTextField.typeText("https://example.com/article")
        
        // Add content
        let contentTextEditor = app.textViews.firstMatch
        XCTAssertTrue(contentTextEditor.exists)
        contentTextEditor.tap()
        contentTextEditor.typeText("This is the content of my test post with some **bold** formatting.")
        
        // Save the post
        app.buttons["Save"].tap()
        
        // Verify we're back on the blog detail screen and the post is listed
        XCTAssertTrue(app.navigationBars["Test Blog"].exists)
        XCTAssertEqual(app.cells.count, 1)
        
        // Verify the post title is displayed
        XCTAssertTrue(app.staticTexts["Test Post Title"].exists)
        
        // Tap on the post to view its details
        app.cells.element(boundBy: 0).tap()
        
        // Verify post details are displayed
        XCTAssertTrue(app.staticTexts["Test Post Title"].exists)
        
        // Check for the link (Links are represented as buttons in accessibility hierarchy)
        XCTAssertTrue(app.links["https://example.com/article"].exists || 
                     app.buttons["https://example.com/article"].exists)
        
        // Verify content text exists
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'This is the content'")).firstMatch.exists)
    }
    
    func testGenerateSite() throws {
        // Create a blog and navigate to its detail view
        try testCreateAndViewBlog()
        
        // Get a reference to the app
        let app = self.app
        
        // Tap on the blog cell to enter the blog detail view
        app.cells.element(boundBy: 0).tap()
        
        // Verify we're on the blog detail screen
        XCTAssertTrue(app.navigationBars["Test Blog"].exists)
        
        // Create a post using UI interaction rather than calling another test
        // Tap the Add Post button
        app.buttons["Add Post"].tap()
        
        // Fill in the post details
        let titleTextField = app.textFields["Title (optional)"]
        titleTextField.tap()
        titleTextField.typeText("Test Post Title")
        
        let linkTextField = app.textFields["Primary Link (optional)"]
        linkTextField.tap()
        linkTextField.typeText("https://example.com/article")
        
        // Add content
        let contentTextEditor = app.textViews.firstMatch
        contentTextEditor.tap()
        contentTextEditor.typeText("This is the content of my test post.")
        
        // Save the post
        app.buttons["Save"].tap()
        
        // Now we should be back on the blog detail view
        XCTAssertTrue(app.navigationBars["Test Blog"].exists)
        
        // Tap the Publish button (which has a globe icon)
        // Try finding by accessibility label first
        if app.buttons["Publish"].exists {
            app.buttons["Publish"].tap()
        } else {
            // Fall back to the toolbar position if needed
            let buttons = app.navigationBars["Test Blog"].buttons
            if buttons.count >= 2 {
                buttons.element(boundBy: 1).tap() // The Publish button is typically the 2nd button in the toolbar
            }
        }
        
        // Verify the publish view is shown
        XCTAssertTrue(app.staticTexts["Publish Test Blog"].exists)
        
        // Tap the Generate Site button
        app.buttons["Generate Site"].tap()
        
        // Wait for generation to complete and success alert to appear
        let successAlert = app.alerts["Site Generated"]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: successAlert, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
        
        // Verify success alert is shown
        XCTAssertTrue(successAlert.exists)
        
        // Dismiss the alert
        successAlert.buttons["OK"].tap()
        
        // Verify the Share button is now visible
        XCTAssertTrue(app.buttons["Share ZIP File"].exists)
    }
    
    func testDeleteBlog() throws {
        // First create a blog
        try testCreateAndViewBlog()
        
        let app = self.app
        
        // Find the cell containing the blog
        let cell = app.cells.containing(.staticText, identifier: "Test Blog").element
        
        // Swipe left to reveal the delete button
        cell.swipeLeft()
        
        // Tap the delete button that appears after swiping
        app.buttons["Delete"].tap()
        
        // Verify the blog is removed
        XCTAssertEqual(app.cells.count, 0)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}