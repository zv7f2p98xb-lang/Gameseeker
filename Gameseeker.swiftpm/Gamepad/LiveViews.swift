import SwiftUI

/// The controller drawing, wired to the live controller state and user settings.
/// Kept as its own view so only it re-renders on every input change.
struct LiveGamepad: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        GamepadView(state: controllers.state,
                    skin: settings.resolvedSkin(for: controllers.kind),
                    accent: settings.accent.color,
                    coloredFaceButtons: settings.coloredFaceButtons,
                    showBody: settings.showBody)
    }
}

/// Live strip of the most recently pressed buttons.
struct LiveHistory: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings
    var compact = false

    var body: some View {
        InputHistoryView(events: controllers.history,
                         skin: settings.resolvedSkin(for: controllers.kind),
                         accent: settings.accent.color,
                         compact: compact)
    }
}

/// Live numeric readout of the analog inputs.
struct LiveReadout: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        AxisReadout(state: controllers.state, skin: settings.resolvedSkin(for: controllers.kind))
    }
}

struct InputHistoryView: View {
    var events: [InputEvent]
    var skin: PadSkin
    var accent: Color
    var compact = false

    var body: some View {
        let visible = Array(events.suffix(compact ? 8 : 12))
        HStack(spacing: compact ? 4 : 6) {
            ForEach(visible) { event in
                let isNewest = event.id == visible.last?.id
                Text(event.button.label(for: skin))
                    .font(.system(size: compact ? 11 : 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 7 : 10)
                    .padding(.vertical, compact ? 3 : 5)
                    .foregroundStyle(isNewest ? Color.black : Color.white)
                    .background(Capsule().fill(isNewest ? accent : Color.white.opacity(0.14)))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: events)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 22 : 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Son basılan tuşlar")
    }
}

struct AxisReadout: View {
    var state: GamepadState
    var skin: PadSkin

    var body: some View {
        HStack(spacing: 22) {
            item("LX", state.leftStick.x)
            item("LY", state.leftStick.y)
            item("RX", state.rightStick.x)
            item("RY", state.rightStick.y)
            item(PadButton.leftTrigger.label(for: skin), CGFloat(state.value(.leftTrigger)))
            item(PadButton.rightTrigger.label(for: skin), CGFloat(state.value(.rightTrigger)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    private func item(_ name: String, _ value: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(String(format: "%+.2f", Double(value)))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .monospacedDigit()
        }
    }
}
