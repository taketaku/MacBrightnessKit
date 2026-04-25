import CoreGraphics

public protocol DisplayBrightnessBackend: Sendable {
    func allDisplays() -> [DisplayInfo]
    func capability(displayID: CGDirectDisplayID) -> DisplayBrightnessCapability
    func getBrightness(displayID: CGDirectDisplayID) throws -> Float
    func setBrightness(displayID: CGDirectDisplayID, value: Float) throws
}
