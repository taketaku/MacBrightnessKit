import CoreGraphics

public struct DisplayInfo: Sendable, Equatable {
    public let displayID: CGDirectDisplayID
    public let isBuiltin: Bool
    public let name: String

    public init(displayID: CGDirectDisplayID, isBuiltin: Bool, name: String) {
        self.displayID = displayID
        self.isBuiltin = isBuiltin
        self.name = name
    }
}
