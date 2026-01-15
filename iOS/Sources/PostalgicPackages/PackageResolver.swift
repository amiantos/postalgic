// This file exists to satisfy the package structure requirements
// It enables us to use ZIPFoundation as a dependency

import Foundation
import ZIPFoundation

public struct PackageResolver {
    public static func resolveZIPFoundation() -> Bool {
        return true
    }
}