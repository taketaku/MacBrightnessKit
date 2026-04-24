import AppKit
import CoreGraphics
import IOKit

private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
private typealias CanChangeBrightnessFn = @convention(c) (CGDirectDisplayID) -> Bool

// dlopen/dlsym で得られるハンドルと関数ポインタは一度初期化されたら不変のため、
// 並行アクセスしても安全。Swift 6 の Sendable チェックを明示的に緩める。
nonisolated(unsafe) private let displayServicesHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY
)

private let _getBrightness: GetBrightnessFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesGetBrightness")
    else { return nil }
    return unsafeBitCast(sym, to: GetBrightnessFn.self)
}()

private let _setBrightness: SetBrightnessFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesSetBrightness")
    else { return nil }
    return unsafeBitCast(sym, to: SetBrightnessFn.self)
}()

private let _canChangeBrightness: CanChangeBrightnessFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesCanChangeBrightness")
    else { return nil }
    return unsafeBitCast(sym, to: CanChangeBrightnessFn.self)
}()

public struct SystemDisplayBrightnessBackend: DisplayBrightnessBackend {
    public init() {}

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

    private static func displayName(for displayID: CGDirectDisplayID) -> String? {
        for screen in NSScreen.screens {
            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if screenID == displayID {
                return screen.localizedName
            }
        }
        return nil
    }

    public func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        if canUseDisplayServices(displayID: displayID) {
            getDisplayServicesBrightness(displayID: displayID)
        } else {
            getDDCBrightness(displayID: displayID)
        }
    }

    public func setBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        let clamped = max(0.0, min(1.0, value))
        if canUseDisplayServices(displayID: displayID) {
            return setDisplayServicesBrightness(displayID: displayID, value: clamped)
        } else {
            return setDDCBrightness(displayID: displayID, value: clamped)
        }
    }

    // 内蔵ディスプレイに加え、Apple Studio Display / LG UltraFine など DDC/CI を
    // 話さない Apple 製外部ディスプレイも DisplayServices で制御できるため、
    // CGDisplayIsBuiltin ではなく DisplayServicesCanChangeBrightness で分岐する
    private func canUseDisplayServices(displayID: CGDirectDisplayID) -> Bool {
        if CGDisplayIsBuiltin(displayID) != 0 { return true }
        guard let fn = _canChangeBrightness else { return false }
        return fn(displayID)
    }

    // MARK: - DisplayServices (内蔵 + Apple 製外部)

    private func getDisplayServicesBrightness(displayID: CGDirectDisplayID) -> Float? {
        guard let fn = _getBrightness else { return nil }
        var brightness: Float = 0
        let result = fn(displayID, &brightness)
        return result == 0 ? brightness : nil
    }

    private func setDisplayServicesBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let fn = _setBrightness else { return false }
        return fn(displayID, value) == 0
    }

    // MARK: - DDC/CI (一般外部ディスプレイ)

    private func getDDCBrightness(displayID: CGDirectDisplayID) -> Float? {
        guard let raw = DDCHelper.read(displayID: displayID, command: DDCHelper.brightnessVCPCode) else {
            return nil
        }
        return Float(raw) / 100.0
    }

    private func setDDCBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        let ddcValue = UInt16(max(0, min(100, value * 100)))
        return DDCHelper.write(displayID: displayID, command: DDCHelper.brightnessVCPCode, value: ddcValue)
    }
}
