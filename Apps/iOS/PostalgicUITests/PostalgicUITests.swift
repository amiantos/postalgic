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
        // First create a blog with a post
        try testCreateAndViewPost()
        
        // Navigate back to the blog detail view if needed
        let app = self.app
        if !app.navigationBars["Test Blog"].exists {
            app.buttons["Back"].tap()
        }
        
        // Tap the Publish button
        app.buttons["Publish"].tap()
        
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