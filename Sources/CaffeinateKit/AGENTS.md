## CaffeinateKit

These instructions cover the app's testable logic under `Sources/CaffeinateKit/`.

- Do not import AppKit or SwiftUI here; UI lives in `Sources/Caffeinate/`.
- `AwakeController` is the sole owner of IOKit assertion IDs; always request every `PowerAssertionKind` together so the app keeps parity with `caffeinate -dims`.
- Inject system services, time, sleep, and `UserDefaults` so tests never touch IOKit, `SMAppService`, or `.standard` defaults.
