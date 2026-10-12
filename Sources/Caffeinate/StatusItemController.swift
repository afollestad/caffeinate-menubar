import AppKit
import CaffeinateKit
import SwiftUI

/// Owns the menu bar status item and the anchored popover it toggles.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    /// Must match the imagesets in `Resources/Assets.xcassets`.
    static let activeImageName = "CoffeeMenuBarActive"
    static let idleImageName = "CoffeeMenuBarIdleTemplate"

    private let launchAtLogin: LaunchAtLogin
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var iconTask: Task<Void, Never>?

    init(awake: AwakeController, launchAtLogin: LaunchAtLogin) {
        self.launchAtLogin = launchAtLogin
        super.init()

        let hostingController = NSHostingController(rootView: PopoverView(awake: awake, launchAtLogin: launchAtLogin))
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.setAccessibilityLabel("Caffeinate")
            button.toolTip = "Caffeinate"
        }
        updateIcon(isActive: awake.isActive)
        iconTask = Task { [weak self] in
            for await isActive in Observations({ awake.isActive }) {
                self?.updateIcon(isActive: isActive)
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        launchAtLogin.refresh()
        // The popover's window can only become key once the app is active; until then its controls render dimmed.
        NSApp.activate()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        sender.highlight(true)
    }

    private func updateIcon(isActive: Bool) {
        guard let button = statusItem.button else {
            return
        }
        let image: NSImage?
        if let named = NSImage(named: isActive ? Self.activeImageName : Self.idleImageName) {
            // The active icon keeps its own teal/mint colors; macOS tints the idle one.
            named.isTemplate = !isActive
            image = named
        } else {
            // Covers unbundled runs (`swift run`), where the asset catalog is absent; symbols are templates.
            image = NSImage(systemSymbolName: isActive ? "cup.and.heat.waves.fill" : "cup.and.heat.waves", accessibilityDescription: nil)
        }
        button.image = image
        // Offers a template copy for the highlighted state, so macOS can tint the colored active icon there.
        let highlightedImage = image?.copy() as? NSImage
        highlightedImage?.isTemplate = true
        button.alternateImage = highlightedImage
        button.setAccessibilityValue(isActive ? "Stay awake on" : "Stay awake off")
    }
}
