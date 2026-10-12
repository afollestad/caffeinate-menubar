import Foundation
import IOKit.pwr_mgt
import ServiceManagement
@testable import CaffeinateKit

@MainActor
final class FakePowerAssertionClient: PowerAssertionClient {
    var failingKinds: Set<PowerAssertionKind> = []
    private(set) var created: [PowerAssertionKind] = []
    private(set) var released: [IOPMAssertionID] = []
    private(set) var held: [IOPMAssertionID: PowerAssertionKind] = [:]
    private var nextID: IOPMAssertionID = 1

    func create(_ kind: PowerAssertionKind, reason: String) -> IOPMAssertionID? {
        guard !failingKinds.contains(kind) else {
            return nil
        }
        let id = nextID
        nextID += 1
        created.append(kind)
        held[id] = kind
        return id
    }

    func release(_ id: IOPMAssertionID) {
        released.append(id)
        held[id] = nil
    }
}

@MainActor
final class FakeLoginItemService: LoginItemService {
    struct Failure: Error {}

    var status: SMAppService.Status = .notRegistered
    var failure: Failure?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        registerCount += 1
        if let failure {
            throw failure
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let failure {
            throw failure
        }
        status = .notRegistered
    }
}

@MainActor
final class FakeClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
}
