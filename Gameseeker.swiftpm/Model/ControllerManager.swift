import GameController
import Observation
import QuartzCore
import UIKit

/// Tracks the active game controller and publishes its input state once per display frame.
///
/// iPadOS only delivers controller input to the app in the foreground, so this works
/// while Gameseeker itself is on screen (viewer mode or the in-app cloud game).
@MainActor
@Observable
final class ControllerManager {
    private(set) var state = GamepadState.idle
    private(set) var isConnected = false
    private(set) var controllerName = ""
    private(set) var kind: ControllerKind = .generic
    private(set) var batteryLevel: Float? = nil
    private(set) var isCharging = false
    /// Recently pressed buttons, oldest first.
    private(set) var history: [InputEvent] = []

    @ObservationIgnored private var controller: GCController? = nil
    @ObservationIgnored private var displayLink: CADisplayLink? = nil
    @ObservationIgnored private var displayLinkTarget: DisplayLinkTarget? = nil
    @ObservationIgnored private var listeners: [UUID: (GamepadState?) -> Void] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var nextEventID = 0
    @ObservationIgnored private var lastBatteryCheck: CFTimeInterval = 0

    static let historyLifetime: CFTimeInterval = 4
    static let historyLimit = 14

    init() {
        let names: [Notification.Name] = [
            .GCControllerDidConnect,
            .GCControllerDidDisconnect,
            .GCControllerDidBecomeCurrent,
            .GCControllerDidStopBeingCurrent,
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.selectController()
                }
            }
            observers.append(token)
        }
        selectController()
        startPolling()
    }

    // MARK: - Listeners (used by the web gamepad bridge)

    /// Registers a callback that receives every state change (`nil` = no controller).
    func addListener(_ listener: @escaping (GamepadState?) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        listener(isConnected ? state : nil)
        return id
    }

    func removeListener(_ id: UUID) {
        listeners[id] = nil
    }

    private func notifyListeners() {
        guard !listeners.isEmpty else { return }
        let snapshot: GamepadState? = isConnected ? state : nil
        for listener in listeners.values {
            listener(snapshot)
        }
    }

    // MARK: - Controller selection

    private func selectController() {
        let current = GCController.current
        let candidate = current?.extendedGamepad != nil
            ? current
            : GCController.controllers().first { $0.extendedGamepad != nil }
        controller = candidate

        if let candidate, let pad = candidate.extendedGamepad {
            isConnected = true
            controllerName = candidate.vendorName ?? candidate.productCategory
            kind = ControllerKind(pad: pad, category: candidate.productCategory)
            updateBattery()
            poll()
        } else {
            isConnected = false
            controllerName = ""
            kind = .generic
            batteryLevel = nil
            isCharging = false
            if state != .idle {
                state = .idle
            }
        }
        notifyListeners()
    }

    // MARK: - Polling

    private func startPolling() {
        let target = DisplayLinkTarget { [weak self] in
            self?.poll()
        }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLinkTarget = target
        displayLink = link
    }

    private func poll() {
        let now = CACurrentMediaTime()
        pruneHistory(now: now)

        guard let pad = controller?.extendedGamepad else { return }

        var next = GamepadState()
        read(pad, into: &next)
        if next != state {
            recordPresses(from: state, to: next, at: now)
            state = next
            notifyListeners()
        }

        if now - lastBatteryCheck > 2 {
            updateBattery()
        }
    }

    private func read(_ pad: GCExtendedGamepad, into s: inout GamepadState) {
        func put(_ button: PadButton, _ input: GCControllerButtonInput?) {
            guard let input else { return }
            s.values[button.rawValue] = input.value
            s.pressed[button.rawValue] = input.isPressed
        }

        put(.south, pad.buttonA)
        put(.east, pad.buttonB)
        put(.west, pad.buttonX)
        put(.north, pad.buttonY)
        put(.leftShoulder, pad.leftShoulder)
        put(.rightShoulder, pad.rightShoulder)
        put(.leftTrigger, pad.leftTrigger)
        put(.rightTrigger, pad.rightTrigger)
        put(.view, pad.buttonOptions)
        put(.menu, pad.buttonMenu)
        put(.leftStick, pad.leftThumbstickButton)
        put(.rightStick, pad.rightThumbstickButton)
        put(.dpadUp, pad.dpad.up)
        put(.dpadDown, pad.dpad.down)
        put(.dpadLeft, pad.dpad.left)
        put(.dpadRight, pad.dpad.right)
        put(.home, pad.buttonHome)

        if let dualSense = pad as? GCDualSenseGamepad {
            put(.aux, dualSense.touchpadButton)
        } else if let dualShock = pad as? GCDualShockGamepad {
            put(.aux, dualShock.touchpadButton)
        } else if let xbox = pad as? GCXboxGamepad {
            put(.aux, xbox.buttonShare)
        }

        s.leftStick = CGPoint(x: CGFloat(pad.leftThumbstick.xAxis.value),
                              y: CGFloat(pad.leftThumbstick.yAxis.value))
        s.rightStick = CGPoint(x: CGFloat(pad.rightThumbstick.xAxis.value),
                               y: CGFloat(pad.rightThumbstick.yAxis.value))
    }

    // MARK: - History

    private func recordPresses(from old: GamepadState, to new: GamepadState, at time: CFTimeInterval) {
        var added: [InputEvent] = []
        for button in PadButton.allCases where new.pressed[button.rawValue] && !old.pressed[button.rawValue] {
            added.append(InputEvent(id: nextEventID, button: button, time: time))
            nextEventID += 1
        }
        guard !added.isEmpty else { return }
        var updated = history + added
        if updated.count > Self.historyLimit {
            updated.removeFirst(updated.count - Self.historyLimit)
        }
        history = updated
    }

    private func pruneHistory(now: CFTimeInterval) {
        guard let first = history.first, now - first.time > Self.historyLifetime else { return }
        history.removeAll { now - $0.time > Self.historyLifetime }
    }

    // MARK: - Battery

    private func updateBattery() {
        lastBatteryCheck = CACurrentMediaTime()
        guard let battery = controller?.battery, battery.batteryState != .unknown else {
            if batteryLevel != nil { batteryLevel = nil }
            if isCharging { isCharging = false }
            return
        }
        let level = battery.batteryLevel
        let charging = battery.batteryState == .charging || battery.batteryState == .full
        if batteryLevel != level { batteryLevel = level }
        if isCharging != charging { isCharging = charging }
    }
}

extension ControllerKind {
    init(pad: GCExtendedGamepad, category: String) {
        if pad is GCDualSenseGamepad || pad is GCDualShockGamepad {
            self = .playstation
        } else if pad is GCXboxGamepad {
            self = .xbox
        } else if ["switch", "joy-con", "nintendo"].contains(where: { category.localizedCaseInsensitiveContains($0) }) {
            self = .nintendo
        } else {
            self = .generic
        }
    }
}

/// CADisplayLink needs an Objective-C target; this forwards ticks to a closure
/// without creating a retain cycle with the manager.
@MainActor
private final class DisplayLinkTarget: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func tick() {
        handler()
    }
}
