import Foundation

/// Converts between DDC raw values (current / max) and normalized 0.0-1.0 values.
///
/// The DDC/CI VCP "Brightness" max value varies per display (typically 100; some LG models
/// report 150, some EIZO ColorEdge models report 200). This type absorbs the
/// normalization / denormalization so upper layers can always work in 0.0-1.0.
enum BrightnessNormalizer {
    /// Fallback denominator used when max=0 (malformed reply). Common VCP default.
    static let fallbackMax: UInt16 = 100

    /// Normalizes a DDC raw value into the 0.0-1.0 range.
    /// If `max` is 0 then `fallbackMax` is used as the denominator, and `current > max`
    /// (which can happen with malformed replies) is clamped to 1.0.
    static func normalize(current: UInt16, max: UInt16) -> Float {
        let denominator: UInt16 = max == 0 ? fallbackMax : max
        let ratio = Float(current) / Float(denominator)
        return Swift.max(0, Swift.min(1, ratio))
    }

    /// Converts a 0.0-1.0 value back to a DDC raw value. Out-of-range inputs are clamped to
    /// 0.0-1.0, multiplied by `max`, and rounded to the nearest integer.
    static func denormalize(value: Float, max: UInt16) -> UInt16 {
        let denominator: UInt16 = max == 0 ? fallbackMax : max
        let clamped = Swift.max(Float(0), Swift.min(Float(1), value))
        return UInt16((Float(denominator) * clamped).rounded())
    }
}
