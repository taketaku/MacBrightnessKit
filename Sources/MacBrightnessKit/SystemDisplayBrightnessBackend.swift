import AppKit
import CoreGraphics
import Foundation

/// Routes brightness operations between the DisplayServices strategy (built-in / Apple-made
/// external displays) and the DDC/CI strategy (generic external displays). The selection
/// happens per call so behavior tracks display hot-plugging without explicit refresh.
public final class SystemDisplayBrightnessBackend: DisplayBrightnessBackend {
    private let displayServices: DisplayServicesBrightness
    private let ddc: DDCBrightness

    public init() {
        self.displayServices = DisplayServicesBrightness()
        self.ddc = DDCBrightness(interface: IOAVServiceDDC())
    }

    public func allDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displayIDs, &displayCount) == .success else { return [] }

        return (0 ..< Int(displayCount)).map { i in
            let id = displayIDs[i]
            let name = Self.displayName(for: id) ?? "Display \(id)"
            return DisplayInfo(displayID: id, isBuiltin: CGDisplayIsBuiltin(id) != 0, name: name)
        }
    }

    public func capability(displayID: CGDirectDisplayID) -> DisplayBrightnessCapability {
        if displayServices.canControl(displayID: displayID) {
            return DisplayBrightnessCapability(isSupported: true, backend: .displayServices)
        }
        if ddc.canControl(displayID: displayID) {
            return DisplayBrightnessCapability(isSupported: true, backend: .ddc)
        }
        return DisplayBrightnessCapability(isSupported: false, backend: .unsupported)
    }

    public func getBrightness(displayID: CGDirectDisplayID) throws -> Float {
        if displayServices.canControl(displayID: displayID) {
            guard let value = displayServices.get(displayID: displayID) else {
                throw MacBrightnessKitError.readFailed(displayID: displayID)
            }
            return value
        }
        if ddc.canControl(displayID: displayID) {
            guard let value = ddc.get(displayID: displayID) else {
                throw MacBrightnessKitError.readFailed(displayID: displayID)
            }
            return value
        }
        throw MacBrightnessKitError.notSupported(displayID: displayID)
    }

    public func setBrightness(displayID: CGDirectDisplayID, value: Float) throws {
        let clamped = max(0.0, min(1.0, value))
        if displayServices.canControl(displayID: displayID) {
            guard displayServices.set(displayID: displayID, value: clamped) else {
                throw MacBrightnessKitError.writeFailed(displayID: displayID)
            }
            return
        }
        if ddc.canControl(displayID: displayID) {
            guard ddc.set(displayID: displayID, value: clamped) else {
                throw MacBrightnessKitError.writeFailed(displayID: displayID)
            }
            return
        }
        throw MacBrightnessKitError.notSupported(displayID: displayID)
    }

    public func diagnose(displayID: CGDirectDisplayID) -> DisplayDiagnostics {
        let ddcReply = ddc.currentAndMax(displayID: displayID)
        let ddcNormalized = ddcReply.map {
            BrightnessNormalizer.normalize(current: $0.current, max: $0.max)
        }

        return DisplayDiagnostics(
            displayID: displayID,
            isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
            canUseDisplayServices: displayServices.canControl(displayID: displayID),
            vendor: CGDisplayVendorNumber(displayID),
            model: CGDisplayModelNumber(displayID),
            displayServicesBrightness: displayServices.get(displayID: displayID),
            ddcBrightness: ddcNormalized,
            ddcMax: ddcReply?.max
        )
    }

    private static func displayName(for displayID: CGDirectDisplayID) -> String? {
        for screen in NSScreen.screens {
            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if screenID == displayID {
                return screen.localizedName
            }
        }
        return nil
    }
}
