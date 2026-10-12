## Bundle Resources

These instructions cover the app bundle inputs under `Resources/`.

- These are not SwiftPM resources; `scripts/build.sh` copies `Info.plist` and compiles the asset catalog and `AppIcon.icon` with `actool`.
- Keep `CFBundleExecutable` equal to the SwiftPM executable product name in `Package.swift`.
- Leave icon keys out of `Info.plist`; `scripts/build.sh` merges them from actool's output.
- Edit `AppIcon.icon` with Icon Composer.
- Keep the menu bar SVGs on an 18 pt canvas. `CoffeeMenuBarIdleTemplate` uses template rendering; `CoffeeMenuBarActive` keeps original colors with a dark-appearance variant.
