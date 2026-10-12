import AppKit

@main
enum CaffeinateApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // The bundle's `LSUIElement` already hides the Dock icon; this covers unbundled runs.
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
