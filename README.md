# MacBrightnessKit

A minimal Swift Package for controlling the brightness of macOS displays — built-in, Apple external displays (Studio Display / LG UltraFine), and generic DDC/CI monitors — through a single unified API.

Extracted from Tenn's macOS app. Licensed under MIT.

## Why

There are several well-known apps that control external display brightness on macOS (MonitorControl, Lunar, BetterDisplay), but none of them are distributed as a Swift Package. If you want to tint, dim, or schedule brightness changes from your own macOS app, you have to either copy their source or reinvent the DDC/CI plumbing.

MacBrightnessKit fills that gap with a four-function API:

```swift
protocol DisplayBrightnessBackend: Sendable {
    func allDisplays() -> [DisplayInfo]
    func capability(displayID: CGDirectDisplayID) -> DisplayBrightnessCapability
    func getBrightness(displayID: CGDirectDisplayID) throws -> Float
    func setBrightness(displayID: CGDirectDisplayID, value: Float) throws
}
```

`getBrightness` and `setBrightness` throw `MacBrightnessKitError` (`.notSupported`, `.readFailed`, `.writeFailed`) so failure reasons are explicit.

All brightness values are normalized to `0.0...1.0` regardless of whether the display is controlled via DisplayServices (which is natively normalized) or DDC/CI (where the raw range varies per display — LG's factory-calibrated displays report `max=150`, EIZO ColorEdge can use `max=200`). The library reads each display's actual DDC max value from the VCP reply and normalizes accordingly.

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/taketaku/MacBrightnessKit", from: "0.1.0")
```

Or add via Xcode → File → Add Package Dependencies.

## Usage

```swift
import MacBrightnessKit

let backend = SystemDisplayBrightnessBackend()

for display in backend.allDisplays() {
    print("\(display.name) (\(display.isBuiltin ? "builtin" : "external"))")
    do {
        let current = try backend.getBrightness(displayID: display.displayID)
        print("  current: \(current)")
        try backend.setBrightness(displayID: display.displayID, value: 0.5)
    } catch {
        print("  skipped: \(error)")
    }
}
```

`value` is in `0.0...1.0`. Values outside the range are clamped.

### Checking display support up front

If you want to filter out displays that won't respond to brightness control before attempting a write, use `capability(displayID:)`:

```swift
let cap = backend.capability(displayID: display.displayID)
if cap.isSupported {
    // cap.backend is .displayServices or .ddc
    try? backend.setBrightness(displayID: display.displayID, value: 0.5)
}
```

## How it works

`SystemDisplayBrightnessBackend` picks one of two strategies per display:

| Path | When | Covers |
|---|---|---|
| **DisplayServices** (Apple private framework) | `DisplayServicesCanChangeBrightness == true` | Built-in MacBook displays, Apple Studio Display, Pro Display XDR, LG UltraFine 4K/5K |
| **DDC/CI** via `IOAVServiceCreateWithService` | fallback | Generic external monitors that speak DDC/CI (most Dell/BenQ/LG/Samsung monitors), Apple Silicon only |

Selection is automatic — you don't need to know which kind of display you have. Use `capability(displayID:)` if you want to query support up front instead of attempting a write.

### Architecture

```
SystemDisplayBrightnessBackend  (router, public)
  ├─ DisplayServicesBrightness  (strategy: built-in + Apple-made external)
  └─ DDCBrightness              (strategy: generic external; holds per-display max-value cache)
       └─ DDCInterface          (I/O abstraction protocol)
            └─ IOAVServiceDDC   (system implementation)

DDCHelper            (pure: VCP packet decoding, EDID parsing, checksum)
BrightnessNormalizer (pure: 0.0–1.0 ↔ DDC raw conversion with per-display max)
```

The `DDCInterface` protocol lets tests substitute a mock for hardware-free verification of DDC normalization, max-cache priming, and write call sequencing.

## Trying it out

The package ships a CLI `macbrightness` (built from the `MacBrightnessKitDemo` target) so you can verify the library against your own hardware without writing a host app.

```sh
git clone https://github.com/taketaku/MacBrightnessKit
cd MacBrightnessKit

swift run macbrightness list
# displayID     kind      name
# --------------------------------------------------
# 1             builtin   Built-in Retina Display
# 2             external  DELL U2723QE

swift run macbrightness get 1
# 0.750

swift run macbrightness set 2 0.5
# ok
```

The CLI is a separate product from the library. When you add MacBrightnessKit as a Swift Package dependency to your own app, link only the `MacBrightnessKit` library product — the `macbrightness` executable is not pulled in.

## Platform support

- **macOS 26+** required
- **Swift 6.3+** required
- **Apple Silicon only** for the DDC/CI path. Intel Mac DDC/CI support would require an `IOFramebufferI2CInterface` implementation — contributions welcome.

## Compatibility Matrix

What MacBrightnessKit can and cannot do, by display category. ✅ = expected to work, ⚠️ = caveat, ❌ = unsupported.

| Display category | Backend | `get` | `set` | Notes |
|---|---|---|---|---|
| MacBook built-in display | DisplayServices | ✅ | ✅ | `DisplayServicesBrightnessChanged` is called after set to defeat auto-brightness reverting the value |
| iMac built-in display | DisplayServices | ✅ | ✅ | Theoretical — needs hardware verification |
| Apple Studio Display | DisplayServices | ✅ | ✅ | Theoretical — needs hardware verification |
| Pro Display XDR | DisplayServices | ✅ | ✅ | Theoretical — needs hardware verification |
| LG UltraFine 4K / 5K | DisplayServices | ✅ | ✅ | Theoretical — Apple treats these as Apple-managed displays |
| Generic DDC/CI external (Apple Silicon) | DDC/CI | ✅ | ✅ | Most Dell / BenQ / LG / Samsung / Acer monitors. Per-display `max` value is auto-detected and normalized to `0.0...1.0` |
| DisplayLink-based adapters / docks | unsupported | ❌ | ❌ | DDC does not pass through DisplayLink |
| Cheap HDMI / DP → USB-C adapters | depends | ⚠️ | ⚠️ | Pass-through often works; some adapters strip the I2C side-channel |
| Intel Mac + any external display | unsupported | ❌ | ❌ | DDC path uses `IOAVServiceCreateWithService`, which is Apple-Silicon only. Contributions for an `IOFramebufferI2CInterface` fallback are welcome |
| Non-0x10 VCP devices (some TVs, projectors, HDR) | unsupported | ❌ | ❌ | The library only implements VCP code `0x10` (luminance) |

`capability(displayID:)` returns `.displayServices` / `.ddc` / `.unsupported` so apps can filter the list before showing UI.

## Verified Hardware

Concrete devices the maintainer or contributors have physically verified. Theoretical entries above are not duplicated here — only items in this table have first-hand evidence.

| Vendor | Model | Connection | Path | DDC max | Verified machine | Verified by |
|---|---|---|---|---|---|---|
| Apple (PNP "APP", 0x0610) | Built-in Retina Display (0xA052) | — (built-in) | DisplayServices | — | M2 MacBook Air | @taketaku |
| Pixio (PNP "PXO", 0x430F) | PX275CP (0x2700) | USB-C | DDC/CI | 100 | M2 MacBook Air | @taketaku |

To add your display, open a PR that edits this section. See [the PR template](.github/PULL_REQUEST_TEMPLATE.md) for the required fields. The maintainer accepts hardware-verified PRs without re-verification — see [Contributing](#contributing).

## Contributing

This library needs hardware diversity that the original author can't cover alone. The policy is:

1. **PRs with verified hardware → merged without physical re-verification by maintainer.** You must fill out the "Tested on" section of the PR template with concrete device information.
2. **CI runs `swift build` + pure-logic unit tests only.** Hardware-dependent paths are not tested automatically.
3. **Issue reports with `Display Info` dump help triage.** Include `allDisplays()` output, `CGDisplayVendorNumber`, `CGDisplayModelNumber`, and the result of `getBrightness` / `setBrightness`.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Inspired by and partially derived from the techniques documented in [MonitorControl](https://github.com/MonitorControl/MonitorControl), [m1ddc](https://github.com/waydabber/m1ddc), and [ddcctl](https://github.com/kfix/ddcctl). None of these are used as dependencies — their source code served as reference for the DDC/CI protocol and VCP codes.
