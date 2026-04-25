import Foundation
import Testing
@testable import MacBrightnessKit

@Suite("DDCHelper pure logic")
struct DDCHelperTests {
    @Test("ddcChecksum for brightness read frame")
    func checksumRead() {
        let sendData: [UInt8] = [0x82, 0x01, 0x10, 0x00]
        let checksum = DDCHelper.ddcChecksum(sendData)
        // 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ 0x10 = 0xAC
        #expect(checksum == 0xAC)
    }

    @Test("ddcChecksum for brightness write frame value=75")
    func checksumWrite75() {
        let sendData: [UInt8] = [0x84, 0x03, 0x10, 0x00, 0x4B, 0x00]
        let checksum = DDCHelper.ddcChecksum(sendData)
        // XOR with 0x00 is identity, so skipping zero bytes gives same result
        // 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x4B = 0xE3
        #expect(checksum == 0xE3)
    }

    @Test("ddcChecksum for brightness write frame value=100")
    func checksumWrite100() {
        let sendData: [UInt8] = [0x84, 0x03, 0x10, 0x00, 0x64, 0x00]
        let checksum = DDCHelper.ddcChecksum(sendData)
        // 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x64 = 0xCC
        #expect(checksum == 0xCC)
    }

    @Test("vendorFromEDID extracts bytes 8-9 big-endian")
    func vendorParse() {
        var edid = Data(repeating: 0, count: 128)
        edid[8] = 0x10
        edid[9] = 0xAC
        #expect(DDCHelper.vendorFromEDID(edid) == 0x10AC)
    }

    @Test("vendorFromEDID returns 0 for short data")
    func vendorParseShort() {
        let short = Data([0x01, 0x02, 0x03])
        #expect(DDCHelper.vendorFromEDID(short) == 0)
    }

    @Test("modelFromEDID extracts bytes 11-10 little-endian")
    func modelParse() {
        var edid = Data(repeating: 0, count: 128)
        edid[10] = 0x34
        edid[11] = 0x12
        #expect(DDCHelper.modelFromEDID(edid) == 0x1234)
    }

    @Test("modelFromEDID returns 0 for short data")
    func modelParseShort() {
        let short = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A])
        #expect(DDCHelper.modelFromEDID(short) == 0)
    }

    // MARK: - decodeVCPReply

    @Test("decodeVCPReply extracts current from bytes 8-9 and max from 6-7")
    func decodeReplyTypical() {
        // current=50 (0x0032), max=100 (0x0064)
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00]
        let decoded = DDCHelper.decodeVCPReply(bytes)
        #expect(decoded?.current == 50)
        #expect(decoded?.max == 100)
    }

    @Test("decodeVCPReply handles non-100 max (LG-style 150)")
    func decodeReplyMax150() {
        // max=150 (0x0096), current=75 (0x004B) → normalizes to 0.5
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x96, 0x00, 0x4B, 0x00]
        let decoded = DDCHelper.decodeVCPReply(bytes)
        #expect(decoded?.current == 75)
        #expect(decoded?.max == 150)
    }

    @Test("decodeVCPReply handles 16-bit max value")
    func decodeReplyLargeMax() {
        // max=0x0200 (512), current=0x0100 (256)
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00]
        let decoded = DDCHelper.decodeVCPReply(bytes)
        #expect(decoded?.current == 256)
        #expect(decoded?.max == 512)
    }

    @Test("decodeVCPReply returns nil for short data")
    func decodeReplyShort() {
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64]  // 8 bytes
        #expect(DDCHelper.decodeVCPReply(bytes) == nil)
    }
}
