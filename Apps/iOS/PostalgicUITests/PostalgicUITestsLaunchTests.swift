//
//  PostalgicUITestsLaunchTests.swift
//  PostalgicUITests
//
//  Created by Brad Root on 4/19/25.
//

import XCTest

final class PostalgicUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()

        // Verify we're on the Blogs screen
        XCTAssertTrue(app.navigationBars["Blogs"].exists)

        // Take a screenshot of the launch screen
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
