import CoreGraphics
import Foundation

/// Pure DDC/CI helpers — packet decoding, EDID parsing, and checksum computation.
/// I/O lives in `IOAVServiceDDC`; routing and caching live in `DDCBrightness`.
enum DDCHelper {
    static let brightnessVCPCode: UInt8 = 0x10

    /// Pure function that extracts current / max from a DDC/CI "Get VCP Feature Reply" packet.
    ///
    /// Packet layout (typical):
    ///   [0] 0x6E source / [1] length / [2] 0x02 reply opcode / [3] result code
    ///   [4] VCP code echo / [5] type / [6][7] MAX value / [8][9] CURRENT value / [10] checksum
    static func decodeVCPReply(_ bytes: [UInt8]) -> (current: UInt16, max: UInt16)? {
        guard bytes.count >= 10 else { return nil }
        let maxValue = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
        let current = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
        return (current: current, max: maxValue)
    }

    // MARK: - EDID Parsing

    static func vendorFromEDID(_ edid: Data) -> UInt32 {
        guard edid.count >= 10 else { return 0 }
        return UInt32(edid[8]) << 8 | UInt32(edid[9])
    }

    static func modelFromEDID(_ edid: Data) -> UInt32 {
        guard edid.count >= 12 else { return 0 }
        return UInt32(edid[11]) << 8 | UInt32(edid[10])
    }

    // MARK: - Checksum

    static func ddcChecksum(_ bytes: [UInt8]) -> UInt8 {
        var xor: UInt8 = 0x6E ^ 0x51
        for byte in bytes where byte != bytes.last {
            xor ^= byte
        }
        return xor
    }
}
