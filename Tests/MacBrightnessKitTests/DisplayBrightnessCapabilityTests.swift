import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("DisplayBrightnessCapability")
struct DisplayBrightnessCapabilityTests {
    @Test("equality by isSupported and backend")
    func equality() {
        let a = DisplayBrightnessCapability(isSupported: true, backend: .ddc)
        let b = DisplayBrightnessCapability(isSupported: true, backend: .ddc)
        let c = DisplayBrightnessCapability(isSupported: true, backend: .displayServices)
        let d = DisplayBrightnessCapability(isSupported: false, backend: .unsupported)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }
}
