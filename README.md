# MacBrightnessKit

A minimal Swift Package for controlling the brightness of macOS displays — built-in, Apple external displays (Studio Display / LG UltraFine), and generic DDC/CI monitors — through a single unified API.

Extracted from [Tenn](https://github.com/taketaku/Tenn)'s macOS app. Licensed under MIT.

## Why

There are several well-known apps that control external display brightness on macOS (MonitorControl, Lunar, BetterDisplay), but none of them are distributed as a Swift Package. If you want to tint, dim, or schedule brightness changes from your own macOS app, you have to either copy their source or reinvent the DDC/CI plumbing.

MacBrightnessKit fills that gap with a three-function API:

```swift
protocol DisplayBrightnessBackend: Sendable {
    func allDisplays() -> [DisplayInfo]
    func getBrightness(displayID: CGDirectDisplayID) -> Float?
    func setBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool
}
```

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
    if let current = backend.getBrightness(displayID: display.displayID) {
        print("  current: \(current)")
    }
    _ = backend.setBrightness(displayID: display.displayID, value: 0.5)
}
```

`value` is in `0.0...1.0`. Values outside the range are clamped.

## How it works

`SystemDisplayBrightnessBackend` picks one of two paths per display:

| Path | When | Covers |
|---|---|---|
| **DisplayServices** (Apple private framework) | `DisplayServicesCanChangeBrightness == true` | Built-in MacBook displays, Apple Studio Display, Pro Display XDR, LG UltraFine 4K/5K |
| **DDC/CI** via `IOAVServiceCreateWithService` | fallback | Generic external monitors that speak DDC/CI (most Dell/BenQ/LG/Samsung monitors), Apple Silicon only |

Selection is automatic — you don't need to know which kind of display you have.

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

## Tested Displays

Please add your display by opening a PR that edits this section. See [the PR template](.github/PULL_REQUEST_TEMPLATE.md) for the required fields.

| Model | Connection | Chip | Path | Result |
|---|---|---|---|---|
| _(empty — awaiting contributions)_ | | | | |

**Known gaps** (not yet tested or not supported):

- Apple Studio Display — expected to work via DisplayServices, needs hardware verification
- Pro Display XDR — expected to work via DisplayServices, needs hardware verification
- LG UltraFine 4K/5K — expected to work via DisplayServices, needs hardware verification
- Intel Mac + any external display — DDC/CI path uses Apple-Silicon-only API, will silently return false
- DisplayLink / USB-C→HDMI adapters — DDC/CI does not pass through these
- Non-0x10 VCP monitors (some TVs / projectors / HDR displays)

## Contributing

This library needs hardware diversity that the original author can't cover alone. The policy is:

1. **PRs with verified hardware → merged without physical re-verification by maintainer.** You must fill out the "Tested on" section of the PR template with concrete device information.
2. **CI runs `swift build` + pure-logic unit tests only.** Hardware-dependent paths are not tested automatically.
3. **Issue reports with `Display Info` dump help triage.** Include `allDisplays()` output, `CGDisplayVendorNumber`, `CGDisplayModelNumber`, and the result of `getBrightness` / `setBrightness`.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Inspired by and partially derived from the techniques documented in [MonitorControl](https://github.com/MonitorControl/MonitorControl), [m1ddc](https://github.com/waydabber/m1ddc), and [ddcctl](https://github.com/kfix/ddcctl). None of these are used as dependencies — their source code served as reference for the DDC/CI protocol and VCP codes.
