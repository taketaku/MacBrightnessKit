import CoreGraphics
import Foundation

private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
private typealias CanChangeBrightnessFn = @convention(c) (CGDirectDisplayID) -> Bool
private typealias BrightnessChangedFn = @convention(c) (CGDirectDisplayID, Double) -> Int32

// The handle and function pointers obtained via dlopen/dlsym are immutable once
// initialized, so concurrent access is safe. Explicitly relax Swift 6's Sendable check.
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

// DisplayServicesSetBrightness alone may have its value reverted by HID's auto-brightness.
// Calling BrightnessChanged alongside updates HID's cache and makes the change stick.
// (Standard pattern adopted by MonitorControl / Lunar.)
private let _brightnessChanged: BrightnessChangedFn? = {
    guard let handle = displayServicesHandle,
          let sym = dlsym(handle, "DisplayServicesBrightnessChanged")
    else { return nil }
    return unsafeBitCast(sym, to: BrightnessChangedFn.self)
}()

/// Brightness control strategy that talks to Apple's private DisplayServices framework.
/// Covers built-in displays plus Apple-made external displays (Studio Display, LG UltraFine, etc.).
struct DisplayServicesBrightness: Sendable {
    /// In addition to built-in displays, Apple-made external displays that don't speak
    /// DDC/CI can also be controlled via DisplayServices, so we branch on
    /// DisplayServicesCanChangeBrightness rather than CGDisplayIsBuiltin.
    func canControl(displayID: CGDirectDisplayID) -> Bool {
        if CGDisplayIsBuiltin(displayID) != 0 { return true }
        guard let fn = _canChangeBrightness else { return false }
        return fn(displayID)
    }

    func get(displayID: CGDirectDisplayID) -> Float? {
        guard let fn = _getBrightness else { return nil }
        var brightness: Float = 0
        let result = fn(displayID, &brightness)
        return result == 0 ? brightness : nil
    }

    func set(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let fn = _setBrightness else { return false }
        let ok = fn(displayID, value) == 0
        if ok { _ = _brightnessChanged?(displayID, Double(value)) }
        return ok
    }
}
