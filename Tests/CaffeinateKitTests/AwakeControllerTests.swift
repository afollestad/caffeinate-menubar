import Foundation
import Testing
@testable import CaffeinateKit

@MainActor
final class AwakeControllerTests {
    private let suiteName = "AwakeControllerTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let client = FakePowerAssertionClient()
    private let clock = FakeClock()

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test
    func startHoldsEveryDimsAssertionAndStopReleasesThem() {
        let controller = makeController()

        controller.start()
        #expect(controller.isActive)
        #expect(client.created.count == PowerAssertionKind.allCases.count)
        #expect(Set(client.created) == Set(PowerAssertionKind.allCases))

        controller.stop()
        #expect(!controller.isActive)
        #expect(client.held.isEmpty)
        #expect(client.released.count == PowerAssertionKind.allCases.count)
    }

    @Test
    func startWhileActiveIsNoOp() {
        let controller = makeController()
        controller.start()
        controller.start()
        #expect(client.created.count == PowerAssertionKind.allCases.count)
    }

    @Test
    func indefiniteSessionHasNoDeadline() {
        let controller = makeController()
        controller.start()
        #expect(controller.duration == .indefinite)
        #expect(controller.deadline == nil)
        #expect(controller.expiryTask == nil)
    }

    @Test
    func timedSessionExpires() async {
        let controller = makeController(sleep: { _ in })
        controller.duration = AwakeDuration(step: 6)

        controller.start()
        #expect(controller.deadline == clock.now.addingTimeInterval(1_800))

        await controller.expiryTask?.value
        #expect(!controller.isActive)
        #expect(controller.deadline == nil)
        #expect(client.held.isEmpty)
    }

    @Test
    func changingDurationWhileActiveRestartsFromNow() {
        let controller = makeController()
        controller.duration = AwakeDuration(step: 12)
        controller.start()
        let firstTask = controller.expiryTask

        clock.now.addTimeInterval(600)
        controller.duration = AwakeDuration(step: 6)
        #expect(controller.deadline == clock.now.addingTimeInterval(1_800))
        #expect(firstTask?.isCancelled == true)

        controller.duration = .indefinite
        #expect(controller.isActive)
        #expect(controller.deadline == nil)
        #expect(controller.expiryTask == nil)
    }

    @Test
    func cancelledExpiryDoesNotStopRescheduledSession() async {
        // The replaced session's 1-hour sleep finishes despite cancellation; the rescheduled 30-minute one keeps waiting.
        let controller = makeController(sleep: { duration in
            guard duration != .seconds(3_600) else {
                return
            }
            try await Task.sleep(for: .seconds(3_600))
        })
        controller.duration = AwakeDuration(step: 12)
        controller.start()
        let replacedTask = controller.expiryTask

        controller.duration = AwakeDuration(step: 6)
        await replacedTask?.value
        #expect(controller.isActive)
        #expect(client.held.count == PowerAssertionKind.allCases.count)
    }

    @Test
    func stopCancelsPendingExpiry() async {
        let controller = makeController()
        controller.duration = AwakeDuration(step: 1)
        controller.start()
        let task = controller.expiryTask

        controller.stop()
        #expect(task?.isCancelled == true)
        await task?.value
        #expect(!controller.isActive)
        #expect(controller.deadline == nil)
    }

    @Test
    func changingDurationWhileInactivePersistsWithoutAssertions() {
        let controller = makeController()
        controller.duration = AwakeDuration(step: 3)
        #expect(client.created.isEmpty)
        #expect(controller.deadline == nil)
        #expect(makeController().duration == AwakeDuration(step: 3))
    }

    @Test
    func keepsGrantedAssertionsWhenSomeFail() {
        client.failingKinds = [.preventSystemSleep]
        let controller = makeController()
        controller.start()
        #expect(controller.isActive)
        #expect(client.held.count == PowerAssertionKind.allCases.count - 1)
    }

    @Test
    func staysInactiveWhenEveryAssertionFails() {
        client.failingKinds = Set(PowerAssertionKind.allCases)
        let controller = makeController()
        controller.start()
        #expect(!controller.isActive)
        #expect(controller.deadline == nil)
    }

    /// The default sleep never finishes on its own, so expiry happens only when a test chooses an instant sleep.
    private func makeController(
        sleep: @escaping AwakeController.Sleep = { _ in try await Task.sleep(for: .seconds(3_600)) }
    ) -> AwakeController {
        let clock = clock
        return AwakeController(assertionClient: client, defaults: defaults, now: { clock.now }, sleep: sleep)
    }
}
