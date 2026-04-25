## Summary

<!-- Briefly describe what this PR changes. -->

## Tested on (required for hardware-touching PRs)

**If your PR modifies `SystemDisplayBrightnessBackend` or `DDCHelper`, this section is mandatory. PRs that do not fill it out will not be merged.**

| Item | Value |
|---|---|
| Display model | e.g. `Dell U2723QE` |
| Connection | e.g. `USB-C (DisplayPort Alt Mode)` / `HDMI 2.1` / `Thunderbolt 4` |
| Host Mac | e.g. `MacBook Pro 14" M3, macOS 26.x` |
| Path taken | `DisplayServices` / `DDC/CI` / both |
| VCP code (if DDC) | e.g. `0x10` |
| `getBrightness` result | e.g. `0.75` / threw `MacBrightnessKitError.xxx` |
| `setBrightness(displayID:value: 0.5)` result | `success` / threw `MacBrightnessKitError.xxx` |
| Visible change | `yes` / `no` |

## Checklist

- [ ] `swift build` passes locally
- [ ] `swift test` passes locally
- [ ] If this PR touches hardware-dependent code, the "Tested on" section above is filled out with concrete device info
- [ ] If this PR adds support for a new display / chip / connection, `README.md` "Tested Displays" table is updated

## Notes for the maintainer

<!-- Optional. If you encountered quirks worth documenting, put them here. -->
