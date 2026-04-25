import CoreGraphics
import Foundation
import MacBrightnessKit

@main
struct Demo {
    static func main() {
        let args = CommandLine.arguments
        let backend = SystemDisplayBrightnessBackend()

        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        switch args[1] {
        case "list":
            listDisplays(backend: backend)
        case "get":
            guard args.count == 3, let id = parseDisplayID(args[2]) else {
                printUsage()
                exit(1)
            }
            getBrightness(backend: backend, displayID: id)
        case "set":
            guard args.count == 4,
                  let id = parseDisplayID(args[2]),
                  let value = Float(args[3])
            else {
                printUsage()
                exit(1)
            }
            setBrightness(backend: backend, displayID: id, value: value)
        case "diag":
            guard args.count == 3, let id = parseDisplayID(args[2]) else {
                printUsage()
                exit(1)
            }
            diagnose(backend: backend, displayID: id)
        case "capability", "cap":
            guard args.count == 3, let id = parseDisplayID(args[2]) else {
                printUsage()
                exit(1)
            }
            showCapability(backend: backend, displayID: id)
        case "-h", "--help", "help":
            printUsage()
        default:
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        let bin = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "macbrightness"
        print("""
        usage:
          \(bin) list                         List all displays with displayID / kind / name
          \(bin) get <displayID>              Print the display's current brightness (0.0-1.0)
          \(bin) set <displayID> <value>      Set the display's brightness (0.0-1.0)
          \(bin) diag <displayID>             Show backend selection and read results from both paths
          \(bin) capability <displayID>       Report whether brightness control is available

        Examples:
          \(bin) list
          \(bin) set 1 0.5
        """)
    }

    static func parseDisplayID(_ arg: String) -> CGDirectDisplayID? {
        if let decimal = UInt32(arg) { return decimal }
        if arg.hasPrefix("0x"), let hex = UInt32(arg.dropFirst(2), radix: 16) { return hex }
        return nil
    }

    static func listDisplays(backend: DisplayBrightnessBackend) {
        let displays = backend.allDisplays()
        if displays.isEmpty {
            print("(no active displays found)")
            return
        }
        print(pad("displayID", 12) + "  " + pad("kind", 8) + "  name")
        print(String(repeating: "-", count: 50))
        for d in displays {
            let id = pad("\(d.displayID)", 12)
            let kind = pad(d.isBuiltin ? "builtin" : "external", 8)
            print("\(id)  \(kind)  \(d.name)")
        }
    }

    static func pad(_ s: String, _ length: Int) -> String {
        s.count >= length ? s : s + String(repeating: " ", count: length - s.count)
    }

    static func getBrightness(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID) {
        do {
            let value = try backend.getBrightness(displayID: displayID)
            print(String(format: "%.3f", value))
        } catch {
            print("(unable to read brightness: \(error))")
            exit(2)
        }
    }

    static func setBrightness(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID, value: Float) {
        do {
            try backend.setBrightness(displayID: displayID, value: value)
            print("ok")
        } catch {
            print("(failed: \(error))")
            exit(2)
        }
    }

    static func diagnose(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID) {
        guard let system = backend as? SystemDisplayBrightnessBackend else {
            print("(backend does not support diagnostics)")
            exit(2)
        }
        let d = system.diagnose(displayID: displayID)
        func fmt(_ v: Float?) -> String { v.map { String(format: "%.3f", $0) } ?? "nil" }
        let ddcMaxStr = d.ddcMax.map { String($0) } ?? "nil"
        print("""
        displayID:               \(d.displayID)
        isBuiltin:               \(d.isBuiltin)
        canUseDisplayServices:   \(d.canUseDisplayServices)
        vendor:                  \(d.vendor) (0x\(String(d.vendor, radix: 16)))
        model:                   \(d.model) (0x\(String(d.model, radix: 16)))
        DisplayServices read:    \(fmt(d.displayServicesBrightness))
        DDC read:                \(fmt(d.ddcBrightness))
        DDC max:                 \(ddcMaxStr)
        """)
    }

    static func showCapability(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID) {
        let cap = backend.capability(displayID: displayID)
        let backendName: String
        switch cap.backend {
        case .displayServices: backendName = "displayServices"
        case .ddc: backendName = "ddc"
        case .unsupported: backendName = "unsupported"
        }
        print("""
        displayID:    \(displayID)
        isSupported:  \(cap.isSupported)
        backend:      \(backendName)
        """)
    }
}
