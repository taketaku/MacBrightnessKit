import CoreGraphics

public struct DisplayDiagnostics: Sendable {
    public let displayID: CGDirectDisplayID
    public let isBuiltin: Bool
    public let canUseDisplayServices: Bool
    public let vendor: UInt32
    public let model: UInt32
    public let displayServicesBrightness: Float?
    public let ddcBrightness: Float?
    public let ddcMax: UInt16?

    public init(
        displayID: CGDirectDisplayID,
        isBuiltin: Bool,
        canUseDisplayServices: Bool,
        vendor: UInt32,
        model: UInt32,
        displayServicesBrightness: Float?,
        ddcBrightness: Float?,
        ddcMax: UInt16?
    ) {
        self.displayID = displayID
        self.isBuiltin = isBuiltin
        self.canUseDisplayServices = canUseDisplayServices
        self.vendor = vendor
        self.model = model
        self.displayServicesBrightness = displayServicesBrightness
        self.ddcBrightness = ddcBrightness
        self.ddcMax = ddcMax
    }
}
