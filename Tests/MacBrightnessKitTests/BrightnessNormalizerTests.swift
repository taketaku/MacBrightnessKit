import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("BrightnessNormalizer pure logic")
struct BrightnessNormalizerTests {
    // MARK: - normalize

    @Test("normalize standard 0-100 range")
    func normalizeBasic() {
        #expect(BrightnessNormalizer.normalize(current: 0, max: 100) == 0.0)
        #expect(BrightnessNormalizer.normalize(current: 50, max: 100) == 0.5)
        #expect(BrightnessNormalizer.normalize(current: 100, max: 100) == 1.0)
    }

    @Test("normalize with non-100 max (LG-style 150)")
    func normalizeMax150() {
        #expect(BrightnessNormalizer.normalize(current: 75, max: 150) == 0.5)
        #expect(BrightnessNormalizer.normalize(current: 150, max: 150) == 1.0)
    }

    @Test("normalize with non-100 max (EIZO-style 200)")
    func normalizeMax200() {
        #expect(BrightnessNormalizer.normalize(current: 100, max: 200) == 0.5)
    }

    @Test("normalize with max=0 falls back to fallbackMax")
    func normalizeMaxZero() {
        // Falls back to fallbackMax=100 → 50/100 = 0.5
        #expect(BrightnessNormalizer.normalize(current: 50, max: 0) == 0.5)
    }

    @Test("normalize clamps current > max to 1.0")
    func normalizeOverflow() {
        // Clamps to 1.0 when malformed replies report current > max
        #expect(BrightnessNormalizer.normalize(current: 150, max: 100) == 1.0)
    }

    // MARK: - denormalize

    @Test("denormalize standard 0-100 range")
    func denormalizeBasic() {
        #expect(BrightnessNormalizer.denormalize(value: 0.0, max: 100) == 0)
        #expect(BrightnessNormalizer.denormalize(value: 0.5, max: 100) == 50)
        #expect(BrightnessNormalizer.denormalize(value: 1.0, max: 100) == 100)
    }

    @Test("denormalize with non-100 max")
    func denormalizeMax150() {
        #expect(BrightnessNormalizer.denormalize(value: 0.5, max: 150) == 75)
        #expect(BrightnessNormalizer.denormalize(value: 1.0, max: 150) == 150)
    }

    @Test("denormalize clamps below 0 and above 1")
    func denormalizeClamping() {
        #expect(BrightnessNormalizer.denormalize(value: -0.5, max: 100) == 0)
        #expect(BrightnessNormalizer.denormalize(value: 1.5, max: 100) == 100)
    }

    @Test("denormalize rounds to nearest integer")
    func denormalizeRounding() {
        // 0.336 * 100 = 33.6 → 34
        #expect(BrightnessNormalizer.denormalize(value: 0.336, max: 100) == 34)
        // 0.334 * 100 = 33.4 → 33
        #expect(BrightnessNormalizer.denormalize(value: 0.334, max: 100) == 33)
    }

    @Test("denormalize with max=0 falls back to fallbackMax")
    func denormalizeMaxZero() {
        // fallbackMax=100 → 0.5 * 100 = 50
        #expect(BrightnessNormalizer.denormalize(value: 0.5, max: 0) == 50)
    }

    // MARK: - round-trip

    @Test("normalize ∘ denormalize is approximately identity")
    func roundTrip() {
        let cases: [(value: Float, max: UInt16)] = [
            (0.0, 100), (0.5, 100), (1.0, 100),
            (0.5, 150), (0.5, 200),
        ]
        for (value, maxVal) in cases {
            let raw = BrightnessNormalizer.denormalize(value: value, max: maxVal)
            let back = BrightnessNormalizer.normalize(current: raw, max: maxVal)
            #expect(abs(back - value) < 0.01, "round-trip failed for value=\(value) max=\(maxVal)")
        }
    }
}
