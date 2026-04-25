import CoreGraphics
import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("DisplayDiagnostics")
struct DisplayDiagnosticsTests {
    @Test("init stores all fields")
    func initStoresFields() {
        let d = DisplayDiagnostics(
            displayID: 7,
            isBuiltin: false,
            canUseDisplayServices: true,
            vendor: 0x430F,
            model: 0x2700,
            displayServicesBrightness: 0.5,
            ddcBrightness: nil,
            ddcMax: nil
        )
        #expect(d.displayID == 7)
        #expect(d.isBuiltin == false)
        #expect(d.canUseDisplayServices == true)
        #expect(d.vendor == 0x430F)
        #expect(d.model == 0x2700)
        #expect(d.displayServicesBrightness == 0.5)
        #expect(d.ddcBrightness == nil)
        #expect(d.ddcMax == nil)
    }

    @Test("init accepts both DisplayServices-only and DDC-only diagnostic states")
    func bothPaths() {
        let dsOnly = DisplayDiagnostics(
            displayID: 1, isBuiltin: true, canUseDisplayServices: true,
            vendor: 0x0610, model: 0xA052,
            displayServicesBrightness: 0.75, ddcBrightness: nil, ddcMax: nil
        )
        let ddcOnly = DisplayDiagnostics(
            displayID: 2, isBuiltin: false, canUseDisplayServices: false,
            vendor: 0x430F, model: 0x2700,
            displayServicesBrightness: nil, ddcBrightness: 0.5, ddcMax: 100
        )
        #expect(dsOnly.displayServicesBrightness != nil)
        #expect(dsOnly.ddcBrightness == nil)
        #expect(ddcOnly.displayServicesBrightness == nil)
        #expect(ddcOnly.ddcBrightness != nil)
        #expect(ddcOnly.ddcMax == 100)
    }
}
