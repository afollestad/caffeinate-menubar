## Tests

These instructions cover unit tests under `Tests/`.

- Use Swift Testing (`@Test`, `#expect`), not XCTest.
- Use the fakes in `Tests/CaffeinateKitTests/Fakes.swift` and a throwaway `UserDefaults(suiteName:)`; never create real power assertions or login items.
- Await `AwakeController.expiryTask` instead of sleeping to observe expiry.
