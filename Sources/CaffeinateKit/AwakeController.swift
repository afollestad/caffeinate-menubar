import Foundation
import IOKit.pwr_mgt
import Observation
import os

/// Owns the `caffeinate -dims` assertion set while "Stay awake" is on, and ends it when the selected duration elapses.
@MainActor
@Observable
public final class AwakeController {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    static let durationDefaultsKey = "awakeDurationStep"
    static let assertionReason = "Caffeinate: Stay awake"

    public private(set) var isActive = false
    /// When the current session ends; `nil` while inactive or indefinite.
    public private(set) var deadline: Date?
    /// Persisted across launches. Changing it while active restarts the countdown from now.
    public var duration: AwakeDuration {
        didSet {
            // A rounded slider binding re-sends the same step on every drag tick.
            guard duration != oldValue else {
                return
            }
            defaults.set(duration.step, forKey: Self.durationDefaultsKey)
            if isActive {
                scheduleExpiry()
            }
        }
    }

    @ObservationIgnored private let assertionClient: any PowerAssertionClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private var assertionIDs: [IOPMAssertionID] = []
    /// Internal so tests can await expiry instead of sleeping.
    @ObservationIgnored private(set) var expiryTask: Task<Void, Never>?

    /// - Parameter sleep: Defaults to `Task.sleep`, whose continuous clock keeps counting while the Mac sleeps, so a
    ///   session still ends on time after a lid-closed nap.
    public init(
        assertionClient: any PowerAssertionClient = IOKitPowerAssertionClient(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { Date() },
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.assertionClient = assertionClient
        self.defaults = defaults
        self.now = now
        self.sleep = sleep
        duration = AwakeDuration(step: defaults.integer(forKey: Self.durationDefaultsKey))
    }

    isolated deinit {
        expiryTask?.cancel()
        for id in assertionIDs {
            assertionClient.release(id)
        }
    }

    /// Holds whichever assertions macOS grants; stays off only when it grants none.
    public func start() {
        guard !isActive else {
            return
        }
        assertionIDs = PowerAssertionKind.allCases.compactMap { kind in
            let id = assertionClient.create(kind, reason: Self.assertionReason)
            if id == nil {
                logger.error("Failed to create power assertion \(String(describing: kind), privacy: .public)")
            }
            return id
        }
        guard !assertionIDs.isEmpty else {
            return
        }
        isActive = true
        scheduleExpiry()
    }

    public func stop() {
        expiryTask?.cancel()
        expiryTask = nil
        deadline = nil
        for id in assertionIDs {
            assertionClient.release(id)
        }
        assertionIDs = []
        isActive = false
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
        guard let interval = duration.timeInterval else {
            deadline = nil
            return
        }
        deadline = now().addingTimeInterval(interval)
        let sleep = self.sleep
        expiryTask = Task { [weak self] in
            do {
                try await sleep(.seconds(interval))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            self?.stop()
        }
    }
}

private let logger = Logger(subsystem: "com.afollestad.caffeinate", category: "AwakeController")
