import Testing
@testable import CaffeinateKit

@MainActor
struct LaunchAtLoginTests {
    private let service = FakeLoginItemService()

    @Test
    func enablingRegisters() {
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(launchAtLogin.isEnabled)
    }

    @Test
    func disablingWhenUnregisteredSkipsUnregister() {
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.setEnabled(false)
        #expect(service.unregisterCount == 0)
        #expect(!launchAtLogin.isEnabled)
    }

    @Test
    func disablingWhenRegisteredUnregisters() {
        service.status = .enabled
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.setEnabled(false)
        #expect(service.unregisterCount == 1)
        #expect(!launchAtLogin.isEnabled)
    }

    @Test
    func failedWriteKeepsReadBackStatus() {
        service.failure = FakeLoginItemService.Failure()
        let launchAtLogin = LaunchAtLogin(service: service)
        launchAtLogin.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(!launchAtLogin.isEnabled)
    }

    @Test
    func refreshPicksUpSystemSettingsChanges() {
        let launchAtLogin = LaunchAtLogin(service: service)
        service.status = .requiresApproval
        launchAtLogin.refresh()
        #expect(launchAtLogin.isEnabled)
        #expect(launchAtLogin.needsApproval)
    }
}
