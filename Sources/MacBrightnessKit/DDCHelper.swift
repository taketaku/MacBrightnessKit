import CoreGraphics
import Foundation
import IOKit

private typealias IOAVServiceRef = CFTypeRef
private typealias CreateWithServiceFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
private typealias ReadI2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
private typealias WriteI2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

// dlopen/dlsym で得られるハンドルと関数ポインタは一度初期化されたら不変のため、
// 並行アクセスしても安全。Swift 6 の Sendable チェックを明示的に緩める。
nonisolated(unsafe) private let ioKitHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY
)

private let _createWithService: CreateWithServiceFn? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceCreateWithService") else { return nil }
    return unsafeBitCast(sym, to: CreateWithServiceFn.self)
}()

private let _readI2C: ReadI2CFn? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceReadI2C") else { return nil }
    return unsafeBitCast(sym, to: ReadI2CFn.self)
}()

private let _writeI2C: WriteI2CFn? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceWriteI2C") else { return nil }
    return unsafeBitCast(sym, to: WriteI2CFn.self)
}()

/// DDC/CI（Apple Silicon IOAVService 経由）で外部ディスプレイの VCP を読み書きする
enum DDCHelper {
    static let brightnessVCPCode: UInt8 = 0x10

    static func read(displayID: CGDirectDisplayID, command: UInt8) -> UInt16? {
        guard CGDisplayIsBuiltin(displayID) == 0,
              let avService = createAVService(for: displayID),
              let writeI2C = _writeI2C,
              let readI2C = _readI2C
        else { return nil }

        var sendData: [UInt8] = [0x82, 0x01, command, 0x00]
        sendData[3] = ddcChecksum(sendData)

        let sendResult = sendData.withUnsafeMutableBytes { buf in
            writeI2C(avService, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        }
        guard sendResult == KERN_SUCCESS else { return nil }

        usleep(50000)

        var replyData = [UInt8](repeating: 0, count: 11)
        let readResult = replyData.withUnsafeMutableBytes { buf in
            readI2C(avService, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        }
        guard readResult == KERN_SUCCESS else { return nil }

        return (UInt16(replyData[6]) << 8) | UInt16(replyData[7])
    }

    static func write(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool {
        guard CGDisplayIsBuiltin(displayID) == 0,
              let avService = createAVService(for: displayID),
              let writeI2C = _writeI2C
        else { return false }

        var sendData: [UInt8] = [
            0x84, 0x03, command,
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
            0x00
        ]
        sendData[5] = ddcChecksum(sendData)

        return sendData.withUnsafeMutableBytes { buf in
            writeI2C(avService, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        } == KERN_SUCCESS
    }

    // MARK: - AVService Lookup

    private static func createAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
        guard let createFn = _createWithService else { return nil }

        let targetVendor = CGDisplayVendorNumber(displayID)
        let targetModel = CGDisplayModelNumber(displayID)

        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("DCPAVServiceProxy"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any]
            else { continue }

            let location = dict["Location"] as? String ?? ""
            let isBuiltin = location.lowercased().contains("embedded") || location.lowercased().contains("internal")
            if isBuiltin { continue }

            // vendor/model でマッチングして複数外部ディスプレイを区別
            if let edid = dict["EDID"] as? Data, edid.count >= 12 {
                let edidVendor = vendorFromEDID(edid)
                let edidModel = modelFromEDID(edid)
                if edidVendor != targetVendor || edidModel != targetModel {
                    continue
                }
            }

            guard let raw = createFn(kCFAllocatorDefault, service) else { continue }
            return raw.takeRetainedValue()
        }

        return nil
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
