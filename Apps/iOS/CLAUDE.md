# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands
- Build: `xcodebuild -scheme Postalgic -configuration Debug` 
- UI Tests: `xcodebuild test -scheme Postalgic -destination 'platform=iOS Simulator,name=iPhone 15'`
- Single Unit Test: `xcodebuild test -scheme Postalgic -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PostalgicTests/PostalgicTests/testName`
- Single UI Test: `xcodebuild test -scheme Postalgic -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PostalgicUITests/PostalgicUITests/testName`

## Code Style Guidelines
- **Imports**: Group imports with Foundation/UIKit first, followed by SwiftUI/SwiftData, then custom modules
- **Formatting**: 4-space indentation, no trailing whitespace
- **Types**: Use strong typing, avoid 'Any' when possible. Prefer value types over reference types
- **Naming**: Use camelCase for variables/functions, PascalCase for types, prefer descriptive names
- **Access Control**: Use the most restrictive level appropriate (private, fileprivate, internal)
- **Error Handling**: Use do/catch with meaningful error messages instead of force unwrapping
- **SwiftUI Patterns**: Use @State, @Binding, @Environment appropriately. Separate complex views into subviews
- **Documentation**: Add comments for complex logic. Use /// for documentation comments