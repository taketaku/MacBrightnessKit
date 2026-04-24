---
name: Display compatibility report
about: Report whether your display works with MacBrightnessKit
labels: hardware-report
---

## Display info

| Item | Value |
|---|---|
| Model | e.g. `Dell U2723QE` |
| Connection | e.g. `USB-C (DisplayPort Alt Mode)` |
| Host Mac | e.g. `MacBook Pro 14" M3, macOS 14.5` |

## `allDisplays()` output

```
// paste the result of backend.allDisplays() here
```

## `CGDisplayVendorNumber` / `CGDisplayModelNumber`

```
vendor: 0x????
model:  0x????
```

## What happened

- [ ] `setBrightness(value: 0.5)` returned `true`
- [ ] The display actually changed brightness
- [ ] `getBrightness` returned a value
- [ ] Silently returned `false` / `nil` (no error, no change)
- [ ] Crashed / hung

## Expected

<!-- Brief description of what you expected. -->

## Additional context

<!-- Logs, screenshots, etc. -->
