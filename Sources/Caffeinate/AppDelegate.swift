import AppKit
import CaffeinateKit
import ServiceManagement

/// Assertions need no terminate hook: powerd releases them when the process exits.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            awake: AwakeController(),
            launchAtLogin: LaunchAtLogin(service: SMAppService.mainApp)
        )
    }
}
