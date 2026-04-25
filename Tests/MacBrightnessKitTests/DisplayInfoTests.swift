import CoreGraphics
import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("DisplayInfo")
struct DisplayInfoTests {
    @Test("init stores all fields")
    func initStoresFields() {
        let info = DisplayInfo(displayID: 42, isBuiltin: true, name: "Built-in")
        #expect(info.displayID == 42)
        #expect(info.isBuiltin == true)
        #expect(info.name == "Built-in")
    }

    @Test("equality requires all fields to match")
    func equality() {
        let a = DisplayInfo(displayID: 1, isBuiltin: true, name: "A")
        let b = DisplayInfo(displayID: 1, isBuiltin: true, name: "A")
        let differentID = DisplayInfo(displayID: 2, isBuiltin: true, name: "A")
        let differentBuiltin = DisplayInfo(displayID: 1, isBuiltin: false, name: "A")
        let differentName = DisplayInfo(displayID: 1, isBuiltin: true, name: "B")
        #expect(a == b)
        #expect(a != differentID)
        #expect(a != differentBuiltin)
        #expect(a != differentName)
    }
}
