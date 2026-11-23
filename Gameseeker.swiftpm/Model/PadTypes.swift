import CoreGraphics
import Foundation

/// Gamepad buttons in W3C "standard gamepad" order (index == rawValue),
/// plus one auxiliary button (Share / Touchpad / Capture) at index 17.
enum PadButton: Int, CaseIterable, Identifiable {
    case south = 0      // A / Cross / B (Nintendo)
    case east           // B / Circle / A
    case west           // X / Square / Y
    case north          // Y / Triangle / X
    case leftShoulder   // LB / L1 / L
    case rightShoulder  // RB / R1 / R
    case leftTrigger    // LT / L2 / ZL
    case rightTrigger   // RT / R2 / ZR
    case view           // View / Create / −
    case menu           // Menu / Options / +
    case leftStick      // LS / L3
    case rightStick     // RS / R3
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case home
    case aux            // Share / Touchpad / Capture

    var id: Int { rawValue }

    static let count = PadButton.allCases.count
    /// Number of buttons exposed through the W3C standard mapping.
    static let standardCount = 17

    func label(for skin: PadSkin) -> String {
        switch self {
        case .south: return pick(skin, xbox: "A", ps: "✕", nintendo: "B")
        case .east: return pick(skin, xbox: "B", ps: "○", nintendo: "A")
        case .west: return pick(skin, xbox: "X", ps: "□", nintendo: "Y")
        case .north: return pick(skin, xbox: "Y", ps: "△", nintendo: "X")
        case .leftShoulder: return pick(skin, xbox: "LB", ps: "L1", nintendo: "L")
        case .rightShoulder: return pick(skin, xbox: "RB", ps: "R1", nintendo: "R")
        case .leftTrigger: return pick(skin, xbox: "LT", ps: "L2", nintendo: "ZL")
        case .rightTrigger: return pick(skin, xbox: "RT", ps: "R2", nintendo: "ZR")
        case .view: return pick(skin, xbox: "View", ps: "Create", nintendo: "−")
        case .menu: return pick(skin, xbox: "Menu", ps: "Options", nintendo: "+")
        case .leftStick: return pick(skin, xbox: "LS", ps: "L3", nintendo: "LS")
        case .rightStick: return pick(skin, xbox: "RS", ps: "R3", nintendo: "RS")
        case .dpadUp: return "↑"
        case .dpadDown: return "↓"
        case .dpadLeft: return "←"
        case .dpadRight: return "→"
        case .home: return "Home"
        case .aux: return pick(skin, xbox: "Share", ps: "Touchpad", nintendo: "Capture")
        }
    }

    private func pick(_ skin: PadSkin, xbox: String, ps: String, nintendo: String) -> String {
        switch skin {
        case .xbox: return xbox
        case .playstation: return ps
        case .nintendo: return nintendo
        }
    }
}

/// Visual style used to draw the controller.
enum PadSkin: String, CaseIterable, Identifiable {
    case xbox, playstation, nintendo

    var id: String { rawValue }
}

/// What kind of controller is physically connected.
enum ControllerKind: Equatable {
    case xbox, playstation, nintendo, generic

    var preferredSkin: PadSkin {
        switch self {
        case .xbox, .generic: return .xbox
        case .playstation: return .playstation
        case .nintendo: return .nintendo
        }
    }

    var title: String {
        switch self {
        case .xbox: return "Xbox"
        case .playstation: return "PlayStation"
        case .nintendo: return "Nintendo"
        case .generic: return "Genel / MFi"
        }
    }
}

/// A snapshot of every input on the controller.
struct GamepadState: Equatable {
    /// Analog value 0...1 per button (digital buttons are 0 or 1).
    var values = [Float](repeating: 0, count: PadButton.count)
    var pressed = [Bool](repeating: false, count: PadButton.count)
    /// Thumbsticks, -1...1. `y` is positive when the stick is pushed up.
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero

    subscript(_ button: PadButton) -> Bool { pressed[button.rawValue] }

    func value(_ button: PadButton) -> Float { values[button.rawValue] }

    static let idle = GamepadState()
}

/// One entry of the "recently pressed" strip.
struct InputEvent: Identifiable, Equatable {
    let id: Int
    let button: PadButton
    let time: TimeInterval
}

func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
