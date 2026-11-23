import Foundation

/// Feeds the native controller state into the page's W3C Gamepad API.
///
/// WebKit's built-in Gamepad support inside a WKWebView is unreliable (it only sees
/// controllers when the web view is focused at page load). The bridge replaces
/// `navigator.getGamepads()` with a virtual "standard" gamepad that Swift updates
/// every frame from `ControllerManager`, so the game and the overlay always agree.
enum GamepadBridge {
    /// Injected at document start in the main frame.
    static let installScript = #"""
    (() => {
      if (window.__gsBridge) return;
      const BUTTONS = 17;

      const makeButton = () => {
        const button = { pressed: false, touched: false, value: 0 };
        try { if (window.GamepadButton) Object.setPrototypeOf(button, GamepadButton.prototype); } catch (e) {}
        return button;
      };

      const pad = {
        id: 'Gamepad (STANDARD GAMEPAD)',
        index: 0,
        connected: false,
        mapping: 'standard',
        timestamp: 0,
        axes: [0, 0, 0, 0],
        buttons: Array.from({ length: BUTTONS }, makeButton),
        vibrationActuator: {
          type: 'dual-rumble',
          effects: ['dual-rumble', 'trigger-rumble'],
          canPlayEffectType: (type) => type === 'dual-rumble',
          playEffect: () => Promise.resolve('complete'),
          reset: () => Promise.resolve('complete'),
        },
        hapticActuators: [],
      };
      try { if (window.Gamepad) Object.setPrototypeOf(pad, Gamepad.prototype); } catch (e) {}

      let connected = false;

      const fire = (type) => {
        try {
          const event = new Event(type);
          Object.defineProperty(event, 'gamepad', { value: pad });
          window.dispatchEvent(event);
        } catch (e) {}
      };

      const bridge = {
        update(id, buttons, axes) {
          pad.id = id;
          for (let i = 0; i < BUTTONS; i++) {
            const value = buttons[i * 2];
            const pressed = buttons[i * 2 + 1] === 1;
            const button = pad.buttons[i];
            button.value = value;
            button.pressed = pressed;
            button.touched = pressed || value > 0;
          }
          for (let i = 0; i < 4; i++) pad.axes[i] = axes[i];
          pad.timestamp = performance.now();
          if (!connected) {
            connected = true;
            pad.connected = true;
            fire('gamepadconnected');
          }
        },
        disconnect() {
          if (!connected) return;
          connected = false;
          pad.connected = false;
          pad.timestamp = performance.now();
          fire('gamepaddisconnected');
        },
      };
      Object.defineProperty(window, '__gsBridge', { value: bridge });

      const getGamepads = function getGamepads() {
        return connected ? [pad, null, null, null] : [null, null, null, null];
      };
      try { Object.defineProperty(Navigator.prototype, 'getGamepads', { value: getGamepads, configurable: true, writable: true }); } catch (e) {}
      try { Object.defineProperty(navigator, 'getGamepads', { value: getGamepads, configurable: true, writable: true }); } catch (e) {}
    })();
    """#

    /// JavaScript that pushes one state snapshot (or a disconnect) into the page.
    static func updateScript(state: GamepadState?, id: String) -> String {
        guard let state else {
            return "window.__gsBridge&&window.__gsBridge.disconnect();"
        }
        var buttons: [String] = []
        buttons.reserveCapacity(PadButton.standardCount * 2)
        for index in 0..<PadButton.standardCount {
            buttons.append(number(state.values[index]))
            buttons.append(state.pressed[index] ? "1" : "0")
        }
        // Standard mapping: axes are [LX, LY, RX, RY] with Y positive when pushed down.
        let axes = [state.leftStick.x, -state.leftStick.y, state.rightStick.x, -state.rightStick.y]
            .map { number(Float($0)) }
        return "window.__gsBridge&&window.__gsBridge.update(\(jsString(id)),[\(buttons.joined(separator: ","))],[\(axes.joined(separator: ","))]);"
    }

    /// Chrome-style ids so web clients pick the right button glyphs for the controller family.
    static func gamepadID(name: String, kind: ControllerKind) -> String {
        switch kind {
        case .xbox:
            return "Xbox Wireless Controller (STANDARD GAMEPAD Vendor: 045e Product: 0b13)"
        case .playstation:
            return "DualSense Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 0ce6)"
        case .nintendo:
            return "Pro Controller (STANDARD GAMEPAD Vendor: 057e Product: 2009)"
        case .generic:
            return "\(name.isEmpty ? "Gamepad" : name) (STANDARD GAMEPAD)"
        }
    }

    private static func number(_ value: Float) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded == 0 || !rounded.isFinite { return "0" }
        return String(rounded)
    }

    private static func jsString(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"Gamepad\""
        }
        // Strip the surrounding [ ] of the single-element array.
        return String(json.dropFirst().dropLast())
    }
}
