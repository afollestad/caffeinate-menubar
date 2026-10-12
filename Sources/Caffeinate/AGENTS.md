## Caffeinate App Shell

These instructions cover the AppKit/SwiftUI shell under `Sources/Caffeinate/`.

- Keep `StatusItemController`'s image names in sync with the imagesets in `Resources/Assets.xcassets/`.
- Do not give the popover its own background; the system supplies Liquid Glass. Keep `.glassEffect` views inside the `GlassEffectContainer` and never stack glass on glass.
- The app has no Dock icon or main menu (`LSUIElement`), so keep the popover's Quit button.
