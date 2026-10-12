import Observation
import os
import ServiceManagement

/// The login-item surface of `SMAppService`; the seam that keeps tests out of the developer's real login items.
@MainActor
public protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// The app's login-item registration.
///
/// macOS owns this state (the user can change it in System Settings while the app runs), so `status` is read back
/// after every write and should be refreshed before it is shown.
@MainActor
@Observable
public final class LaunchAtLogin {
    public private(set) var status: SMAppService.Status

    @ObservationIgnored private let service: any LoginItemService

    public init(service: any LoginItemService) {
        self.service = service
        status = service.status
    }

    /// Registered, including while System Settings still needs the user's approval.
    public var isEnabled: Bool {
        Self.isRegistered(status)
    }

    public var needsApproval: Bool {
        status == .requiresApproval
    }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else if Self.isRegistered(service.status) {
                // `unregister()` throws when nothing is registered, and "already off" is not a failure.
                try service.unregister()
            }
        } catch {
            let action = enabled ? "register" : "unregister"
            logger.error("Failed to \(action, privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    private static func isRegistered(_ status: SMAppService.Status) -> Bool {
        status == .enabled || status == .requiresApproval
    }
}

private let logger = Logger(subsystem: "com.afollestad.caffeinate", category: "LaunchAtLogin")
