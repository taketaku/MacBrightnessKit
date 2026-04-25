import CoreGraphics

public enum MacBrightnessKitError: Error, Sendable, Equatable {
    /// The display has no controllable backend (built-in DisplayServices nor DDC/CI).
    case notSupported(displayID: CGDirectDisplayID)
    /// A read attempt against the selected backend failed.
    /// For DisplayServices this means the symbol returned a non-zero status; for DDC it means
    /// the I2C transaction failed or the reply could not be parsed.
    case readFailed(displayID: CGDirectDisplayID)
    /// A write attempt against the selected backend failed.
    case writeFailed(displayID: CGDirectDisplayID)
}

extension MacBrightnessKitError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notSupported(let id):
            return "Display \(id) is not supported for brightness control"
        case .readFailed(let id):
            return "Failed to read brightness for display \(id)"
        case .writeFailed(let id):
            return "Failed to write brightness for display \(id)"
        }
    }
}
