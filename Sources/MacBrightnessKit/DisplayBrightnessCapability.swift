import CoreGraphics

/// Indicates whether brightness control is supported on a display, and which backend handles it.
public struct DisplayBrightnessCapability: Sendable, Equatable {
    public enum Backend: Sendable, Equatable {
        case displayServices
        case ddc
        case unsupported
    }

    public let isSupported: Bool
    public let backend: Backend

    public init(isSupported: Bool, backend: Backend) {
        self.isSupported = isSupported
        self.backend = backend
    }
}
