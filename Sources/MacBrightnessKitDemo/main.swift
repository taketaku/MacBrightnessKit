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
          \(bin) list                         全ディスプレイと ID/内蔵外部/名前を表示
          \(bin) get <displayID>              指定ディスプレイの現在輝度を表示 (0.0〜1.0)
          \(bin) set <displayID> <value>      指定ディスプレイの輝度を設定 (0.0〜1.0)

        例:
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
        print(String(format: "%-12s  %-8s  %s", "displayID", "kind", "name"))
        print(String(repeating: "-", count: 50))
        for d in displays {
            print(String(format: "%-12u  %-8s  %s", d.displayID, d.isBuiltin ? "builtin" : "external", d.name))
        }
    }

    static func getBrightness(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID) {
        if let value = backend.getBrightness(displayID: displayID) {
            print(String(format: "%.3f", value))
        } else {
            print("(unable to read brightness)")
            exit(2)
        }
    }

    static func setBrightness(backend: DisplayBrightnessBackend, displayID: CGDirectDisplayID, value: Float) {
        let ok = backend.setBrightness(displayID: displayID, value: value)
        if ok {
            print("ok")
        } else {
            print("(failed)")
            exit(2)
        }
    }
}
