import CoreGraphics
import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("MacBrightnessKitError")
struct MacBrightnessKitErrorTests {
    @Test("equality compares case and associated value")
    func equality() {
        #expect(MacBrightnessKitError.notSupported(displayID: 1) == .notSupported(displayID: 1))
        #expect(MacBrightnessKitError.notSupported(displayID: 1) != .notSupported(displayID: 2))
        #expect(MacBrightnessKitError.readFailed(displayID: 1) != .writeFailed(displayID: 1))
    }

    @Test("description includes displayID")
    func descriptionIncludesID() {
        let error = MacBrightnessKitError.readFailed(displayID: 42)
        #expect(error.description.contains("42"))
        #expect(error.description.contains("read"))
    }

    @Test("notSupported description")
    func notSupportedDescription() {
        let error = MacBrightnessKitError.notSupported(displayID: 7)
        #expect(error.description.contains("7"))
        #expect(error.description.contains("not supported"))
    }
}
