import IOKit.pwr_mgt

/// The power assertions `caffeinate -dims` holds, one per flag.
public enum PowerAssertionKind: CaseIterable, Sendable {
    /// `-d`: prevent the display from idle sleeping.
    case preventDisplaySleep
    /// `-i`: prevent the system from idle sleeping.
    case preventIdleSystemSleep
    /// `-m`: prevent the disk from idle sleeping.
    case preventDiskIdle
    /// `-s`: prevent system sleep entirely; macOS honors it only on AC power.
    case preventSystemSleep

    var assertionType: CFString {
        // Most `kIOPMAssertionType…` names alias other macros and may not import into Swift; use the `kIOPMAssert…` originals.
        switch self {
        case .preventDisplaySleep:
            kIOPMAssertPreventUserIdleDisplaySleep as CFString
        case .preventIdleSystemSleep:
            kIOPMAssertPreventUserIdleSystemSleep as CFString
        case .preventDiskIdle:
            kIOPMAssertPreventDiskIdle as CFString
        case .preventSystemSleep:
            kIOPMAssertionTypePreventSystemSleep as CFString
        }
    }
}

/// Creates and releases IOKit power assertions; the seam that keeps tests off real IOKit.
@MainActor
public protocol PowerAssertionClient: AnyObject {
    func create(_ kind: PowerAssertionKind, reason: String) -> IOPMAssertionID?
    func release(_ id: IOPMAssertionID)
}

public final class IOKitPowerAssertionClient: PowerAssertionClient {
    public init() {}

    public func create(_ kind: PowerAssertionKind, reason: String) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kind.assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }

    public func release(_ id: IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }
}
