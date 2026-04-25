import CoreGraphics
import Foundation
import os

/// Brightness control strategy that talks DDC/CI via the injected `DDCInterface`.
/// Holds a per-display max-value cache so set/get can normalize against the actual VCP max
/// (which varies per display: typically 100, some LG models 150, some EIZO 200).
final class DDCBrightness: Sendable {
    private let interface: any DDCInterface
    private let maxCache = OSAllocatedUnfairLock<[CGDirectDisplayID: UInt16]>(initialState: [:])

    init(interface: any DDCInterface) {
        self.interface = interface
    }

    func canControl(displayID: CGDirectDisplayID) -> Bool {
        interface.hasService(displayID: displayID)
    }

    func get(displayID: CGDirectDisplayID) -> Float? {
        guard let reply = interface.readVCPCurrentAndMax(
            displayID: displayID, command: DDCHelper.brightnessVCPCode
        ) else { return nil }
        cacheMax(displayID: displayID, maxValue: reply.max)
        return BrightnessNormalizer.normalize(current: reply.current, max: reply.max)
    }

    func set(displayID: CGDirectDisplayID, value: Float) -> Bool {
        let maxValue = cachedMax(displayID: displayID)
            ?? primeMaxCache(displayID: displayID)
            ?? BrightnessNormalizer.fallbackMax
        let ddcValue = BrightnessNormalizer.denormalize(value: value, max: maxValue)
        return interface.writeVCPFeature(
            displayID: displayID, command: DDCHelper.brightnessVCPCode, value: ddcValue
        )
    }

    /// Diagnostic accessor that returns the raw current/max pair while populating the cache.
    func currentAndMax(displayID: CGDirectDisplayID) -> (current: UInt16, max: UInt16)? {
        let reply = interface.readVCPCurrentAndMax(
            displayID: displayID, command: DDCHelper.brightnessVCPCode
        )
        if let r = reply { cacheMax(displayID: displayID, maxValue: r.max) }
        return reply
    }

    // MARK: - Cache

    private func cachedMax(displayID: CGDirectDisplayID) -> UInt16? {
        maxCache.withLock { $0[displayID] }
    }

    private func cacheMax(displayID: CGDirectDisplayID, maxValue: UInt16) {
        guard maxValue > 0 else { return }
        maxCache.withLock { $0[displayID] = maxValue }
    }

    /// Used when we need to know `max` before a set. Issues one read and populates the cache.
    private func primeMaxCache(displayID: CGDirectDisplayID) -> UInt16? {
        guard let reply = interface.readVCPCurrentAndMax(
            displayID: displayID, command: DDCHelper.brightnessVCPCode
        ) else { return nil }
        cacheMax(displayID: displayID, maxValue: reply.max)
        return reply.max
    }
}
