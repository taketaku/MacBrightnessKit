import CoreGraphics
import Foundation
import IOKit

/// Abstraction over the I/O surface needed by `DDCBrightness`.
/// `IOAVServiceDDC` is the system implementation; tests can substitute a mock conformer.
protocol DDCInterface: Sendable {
    func readVCPCurrentAndMax(displayID: CGDirectDisplayID, command: UInt8) -> (current: UInt16, max: UInt16)?
    func writeVCPFeature(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool
    func hasService(displayID: CGDirectDisplayID) -> Bool
}

private typealias IOAVServiceRef = CFTypeRef
private typealias CreateWithServiceFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
private typealias ReadI2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
private typealias WriteI2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

// The handle and function pointers obtained via dlopen/dlsym are immutable once
// initialized, so concurrent access is safe. Explicitly relax Swift 6's Sendable check.
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

/// System implementation that drives DDC/CI through Apple Silicon's IOAVService.
struct IOAVServiceDDC: DDCInterface {
    func readVCPCurrentAndMax(displayID: CGDirectDisplayID, command: UInt8) -> (current: UInt16, max: UInt16)? {
        guard let bytes = readVCPFeature(displayID: displayID, command: command) else { return nil }
        return DDCHelper.decodeVCPReply(bytes)
    }

    func writeVCPFeature(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool {
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
        sendData[5] = DDCHelper.ddcChecksum(sendData)

        return sendData.withUnsafeMutableBytes { buf in
            writeI2C(avService, 0x37, 0x51, buf.baseAddress!, UInt32(buf.count))
        } == KERN_SUCCESS
    }

    func hasService(displayID: CGDirectDisplayID) -> Bool {
        createAVService(for: displayID) != nil
    }

    private func readVCPFeature(displayID: CGDirectDisplayID, command: UInt8) -> [UInt8]? {
        guard CGDisplayIsBuiltin(displayID) == 0,
              let avService = createAVService(for: displayID),
              let writeI2C = _writeI2C,
              let readI2C = _readI2C
        else { return nil }

        var sendData: [UInt8] = [0x82, 0x01, command, 0x00]
        sendData[3] = DDCHelper.ddcChecksum(sendData)

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

        return replyData
    }

    private func createAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
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

            // Match by vendor/model to distinguish between multiple external displays.
            if let edid = dict["EDID"] as? Data, edid.count >= 12 {
                let edidVendor = DDCHelper.vendorFromEDID(edid)
                let edidModel = DDCHelper.modelFromEDID(edid)
                if edidVendor != targetVendor || edidModel != targetModel {
                    continue
                }
            }

            guard let raw = createFn(kCFAllocatorDefault, service) else { continue }
            return raw.takeRetainedValue()
        }

        return nil
    }
}
