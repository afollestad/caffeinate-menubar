import AppKit
import CaffeinateKit
import ServiceManagement
import SwiftUI

/// The status item's popover. It relies on the system's Liquid Glass popover background, so it adds none of its own.
struct PopoverView: View {
    /// The app icon's background fill.
    private static let teal = Color(.displayP3, red: 0.17, green: 0.49, blue: 0.46)

    let awake: AwakeController
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider()
                stayAwakeRow
                durationSection
                Divider()
                footer
            }
            .padding(16)
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(awake.isActive ? StatusItemController.activeImageName : StatusItemController.idleImageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                // Not `.white`: inactive windows drop the glass tint, which would leave white on light glass.
                .foregroundStyle(awake.isActive ? .primary : .secondary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(awake.isActive ? Self.teal : nil), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Caffeinate")
                    .font(.headline)
                statusLine
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if !awake.isActive {
            Text("Your Mac can sleep normally")
        } else if let deadline = awake.deadline {
            Text("Until \(deadline, format: .dateTime.hour().minute()) · \(Text(deadline, style: .timer))")
        } else {
            Text("Keeping your Mac awake")
        }
    }

    private var stayAwakeRow: some View {
        HStack {
            Text("Stay awake")
                .font(.body.weight(.medium))
            Spacer()
            Toggle("Stay awake", isOn: Binding(
                get: { awake.isActive },
                set: { $0 ? awake.start() : awake.stop() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Duration")
                Spacer()
                Text(awake.duration.label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // Rounding in the binding snaps to 5-minute steps without the dense tick marks a `step:` slider draws.
            Slider(
                value: Binding(
                    get: { Double(awake.duration.step) },
                    set: { awake.duration = AwakeDuration(step: Int($0.rounded())) }
                ),
                in: 0...Double(AwakeDuration.maxStep)
            ) {
                Text("Duration")
            } minimumValueLabel: {
                Text(Image(systemName: "infinity"))
            } maximumValueLabel: {
                Text(AwakeDuration(step: AwakeDuration.maxStep).label)
            }
            .labelsHidden()
            .accessibilityValue(awake.duration.label)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.glass)
                .keyboardShortcut("q")
            }
            if launchAtLogin.needsApproval {
                Button("Approve in Login Items…") {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }
}
