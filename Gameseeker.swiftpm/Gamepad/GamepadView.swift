import SwiftUI

/// Draws a controller and lights up whatever is being pressed.
/// Everything is drawn in a fixed 400×260 design space and scaled to fit.
struct GamepadView: View {
    var state: GamepadState
    var skin: PadSkin
    var accent: Color
    var coloredFaceButtons = true
    var showBody = true

    var body: some View {
        Canvas { context, size in
            GamepadRenderer(state: state,
                            skin: skin,
                            accent: accent,
                            colored: coloredFaceButtons,
                            showBody: showBody)
                .draw(in: &context, size: size)
        }
        .aspectRatio(PadLayout.designSize.width / PadLayout.designSize.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Oyun kolu görünümü")
    }
}

// MARK: - Layout

struct PadLayout {
    static let designSize = CGSize(width: 400, height: 260)

    var leftStick: CGPoint
    var rightStick: CGPoint
    var dpad: CGPoint
    var face: CGPoint
    var view: CGPoint
    var menu: CGPoint
    var home: CGPoint
    var aux: CGRect
    var leftBumper = CGRect(x: 66, y: 26, width: 86, height: 24)
    var rightBumper = CGRect(x: 248, y: 26, width: 86, height: 24)
    var leftTrigger = CGRect(x: 84, y: 2, width: 56, height: 20)
    var rightTrigger = CGRect(x: 260, y: 2, width: 56, height: 20)

    /// Xbox / Switch Pro style: left stick above the d-pad.
    static let offset = PadLayout(
        leftStick: CGPoint(x: 118, y: 98),
        rightStick: CGPoint(x: 242, y: 150),
        dpad: CGPoint(x: 160, y: 150),
        face: CGPoint(x: 284, y: 98),
        view: CGPoint(x: 174, y: 98),
        menu: CGPoint(x: 226, y: 98),
        home: CGPoint(x: 200, y: 70),
        aux: CGRect(x: 192, y: 110, width: 16, height: 9)
    )

    /// PlayStation style: sticks side by side at the bottom, touchpad in the middle.
    static let symmetric = PadLayout(
        leftStick: CGPoint(x: 152, y: 152),
        rightStick: CGPoint(x: 248, y: 152),
        dpad: CGPoint(x: 106, y: 100),
        face: CGPoint(x: 294, y: 100),
        view: CGPoint(x: 134, y: 62),
        menu: CGPoint(x: 266, y: 62),
        home: CGPoint(x: 200, y: 126),
        aux: CGRect(x: 152, y: 56, width: 96, height: 48)
    )

    static func forSkin(_ skin: PadSkin) -> PadLayout {
        skin == .playstation ? symmetric : offset
    }

    /// Controller silhouette. The left half is described once and mirrored.
    static let bodyPath: Path = {
        let start = CGPoint(x: 200, y: 50)
        let segments: [(c1: CGPoint, c2: CGPoint, end: CGPoint)] = [
            (CGPoint(x: 170, y: 50), CGPoint(x: 150, y: 42), CGPoint(x: 120, y: 42)),
            (CGPoint(x: 90, y: 42), CGPoint(x: 68, y: 50), CGPoint(x: 58, y: 72)),
            (CGPoint(x: 44, y: 104), CGPoint(x: 30, y: 170), CGPoint(x: 36, y: 212)),
            (CGPoint(x: 40, y: 240), CGPoint(x: 72, y: 248), CGPoint(x: 92, y: 238)),
            (CGPoint(x: 108, y: 230), CGPoint(x: 118, y: 212), CGPoint(x: 130, y: 198)),
            (CGPoint(x: 142, y: 190), CGPoint(x: 162, y: 186), CGPoint(x: 200, y: 186)),
        ]
        func mirror(_ p: CGPoint) -> CGPoint { CGPoint(x: PadLayout.designSize.width - p.x, y: p.y) }

        var path = Path()
        path.move(to: start)
        for segment in segments {
            path.addCurve(to: segment.end, control1: segment.c1, control2: segment.c2)
        }
        // Walk the same curves backwards on the mirrored side.
        let segmentStarts = [start] + segments.dropLast().map { $0.end }
        for index in segments.indices.reversed() {
            let segment = segments[index]
            path.addCurve(to: mirror(segmentStarts[index]),
                          control1: mirror(segment.c2),
                          control2: mirror(segment.c1))
        }
        path.closeSubpath()
        return path
    }()
}

// MARK: - Renderer

private enum Palette {
    static let bodyTop = Color(red: 0.24, green: 0.25, blue: 0.29)
    static let bodyBottom = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let bodyStroke = Color.white.opacity(0.10)
    static let control = Color(red: 0.19, green: 0.20, blue: 0.24)
    static let controlStroke = Color.white.opacity(0.16)
    static let well = Color(red: 0.08, green: 0.085, blue: 0.10)
    static let label = Color.white.opacity(0.80)
    static let dimLabel = Color.white.opacity(0.45)
    static let onAccent = Color.black.opacity(0.78)
}

struct GamepadRenderer {
    let state: GamepadState
    let skin: PadSkin
    let accent: Color
    let colored: Bool
    let showBody: Bool

    private var layout: PadLayout { PadLayout.forSkin(skin) }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let design = PadLayout.designSize
        let scale = min(size.width / design.width, size.height / design.height)
        context.translateBy(x: (size.width - design.width * scale) / 2,
                            y: (size.height - design.height * scale) / 2)
        context.scaleBy(x: scale, y: scale)

        drawTriggers(&context)
        drawBumpers(&context)
        if showBody {
            drawBody(&context)
        }
        drawAux(&context)
        drawCenterButtons(&context)
        drawDpad(&context)
        drawFaceButtons(&context)
        drawStick(&context, center: layout.leftStick, value: state.leftStick, button: .leftStick)
        drawStick(&context, center: layout.rightStick, value: state.rightStick, button: .rightStick)
    }

    // MARK: Parts

    private func drawBody(_ ctx: inout GraphicsContext) {
        let shape = PadLayout.bodyPath
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.5), radius: 10, y: 4))
            layer.fill(shape, with: .color(Palette.bodyBottom))
        }
        ctx.fill(shape, with: .linearGradient(Gradient(colors: [Palette.bodyTop, Palette.bodyBottom]),
                                              startPoint: CGPoint(x: 200, y: 40),
                                              endPoint: CGPoint(x: 200, y: 248)))
        ctx.stroke(shape, with: .color(Palette.bodyStroke), lineWidth: 1.5)
    }

    private func drawTriggers(_ ctx: inout GraphicsContext) {
        let items: [(PadButton, CGRect)] = [(.leftTrigger, layout.leftTrigger), (.rightTrigger, layout.rightTrigger)]
        for (button, rect) in items {
            let shape = Path(roundedRect: rect, cornerRadius: 7)
            ctx.fill(shape, with: .color(Palette.control))

            let amount = CGFloat(clamp(state.value(button), 0, 1))
            if amount > 0.01 {
                var fillRect = rect
                fillRect.size.width = rect.width * amount
                if button == .rightTrigger {
                    fillRect.origin.x = rect.maxX - fillRect.width
                }
                let fillColor = accent.opacity(0.35 + 0.65 * Double(amount))
                ctx.drawLayer { layer in
                    layer.clip(to: shape)
                    layer.fill(Path(fillRect), with: .color(fillColor))
                }
            }

            let pressed = state[button]
            ctx.stroke(shape, with: .color(pressed ? accent : Palette.controlStroke), lineWidth: pressed ? 2 : 1.2)
            text(button.label(for: skin), at: CGPoint(x: rect.midX, y: rect.midY), size: 10,
                 color: amount > 0.5 ? Palette.onAccent : Palette.label, &ctx)
        }
    }

    private func drawBumpers(_ ctx: inout GraphicsContext) {
        let items: [(PadButton, CGRect)] = [(.leftShoulder, layout.leftBumper), (.rightShoulder, layout.rightBumper)]
        for (button, rect) in items {
            let shape = Path(roundedRect: rect, cornerRadius: 9)
            let pressed = state[button]
            fillGlow(shape, color: pressed ? accent : Palette.control, glow: pressed, &ctx)
            ctx.stroke(shape, with: .color(pressed ? accent : Palette.controlStroke), lineWidth: 1.2)
            text(button.label(for: skin), at: CGPoint(x: rect.midX, y: rect.minY + 8), size: 9,
                 color: pressed ? Palette.onAccent : Palette.label, &ctx)
        }
    }

    private func drawAux(_ ctx: inout GraphicsContext) {
        let rect = layout.aux
        let pressed = state[.aux]
        let isTouchpad = skin == .playstation
        let shape = Path(roundedRect: rect, cornerRadius: isTouchpad ? 10 : rect.height / 2)
        let idle = isTouchpad ? Palette.well : Palette.control
        fillGlow(shape, color: pressed ? accent : idle, glow: pressed, &ctx)
        ctx.stroke(shape, with: .color(pressed ? accent : Palette.controlStroke), lineWidth: 1.2)
    }

    private enum Glyph {
        case symbol(String)
        case text(String)
    }

    private func drawCenterButtons(_ ctx: inout GraphicsContext) {
        switch skin {
        case .xbox:
            roundButton(.view, center: layout.view, radius: 8, glyph: .symbol("rectangle.on.rectangle"), &ctx)
            roundButton(.menu, center: layout.menu, radius: 8, glyph: .symbol("line.3.horizontal"), &ctx)
            roundButton(.home, center: layout.home, radius: 12, glyph: .symbol("house.fill"), &ctx)
        case .playstation:
            pillButton(.view, center: layout.view, size: CGSize(width: 8, height: 15), &ctx)
            pillButton(.menu, center: layout.menu, size: CGSize(width: 8, height: 15), &ctx)
            roundButton(.home, center: layout.home, radius: 8, glyph: nil, &ctx)
        case .nintendo:
            roundButton(.view, center: layout.view, radius: 8, glyph: .text("−"), &ctx)
            roundButton(.menu, center: layout.menu, radius: 8, glyph: .text("+"), &ctx)
            roundButton(.home, center: layout.home, radius: 11, glyph: .symbol("house.fill"), &ctx)
        }
    }

    private func roundButton(_ button: PadButton, center: CGPoint, radius: CGFloat, glyph: Glyph?, _ ctx: inout GraphicsContext) {
        let pressed = state[button]
        let shape = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        fillGlow(shape, color: pressed ? accent : Palette.control, glow: pressed, &ctx)
        ctx.stroke(shape, with: .color(pressed ? accent : Palette.controlStroke), lineWidth: 1.2)
        let color = pressed ? Palette.onAccent : Palette.label
        switch glyph {
        case .symbol(let name)?:
            symbol(name, at: center, size: radius * 0.9, color: color, &ctx)
        case .text(let string)?:
            text(string, at: center, size: radius * 1.4, color: color, &ctx)
        case nil:
            break
        }
    }

    private func pillButton(_ button: PadButton, center: CGPoint, size: CGSize, _ ctx: inout GraphicsContext) {
        let pressed = state[button]
        let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        let shape = Path(roundedRect: rect, cornerRadius: min(size.width, size.height) / 2)
        fillGlow(shape, color: pressed ? accent : Palette.control, glow: pressed, &ctx)
        ctx.stroke(shape, with: .color(pressed ? accent : Palette.controlStroke), lineWidth: 1.2)
    }

    private func drawDpad(_ ctx: inout GraphicsContext) {
        let c = layout.dpad
        let w: CGFloat = 16
        let l: CGFloat = 17
        let x0 = c.x - w / 2 - l, x1 = c.x - w / 2, x2 = c.x + w / 2, x3 = c.x + w / 2 + l
        let y0 = c.y - w / 2 - l, y1 = c.y - w / 2, y2 = c.y + w / 2, y3 = c.y + w / 2 + l

        var plus = Path()
        plus.addLines([
            CGPoint(x: x1, y: y0), CGPoint(x: x2, y: y0), CGPoint(x: x2, y: y1), CGPoint(x: x3, y: y1),
            CGPoint(x: x3, y: y2), CGPoint(x: x2, y: y2), CGPoint(x: x2, y: y3), CGPoint(x: x1, y: y3),
            CGPoint(x: x1, y: y2), CGPoint(x: x0, y: y2), CGPoint(x: x0, y: y1), CGPoint(x: x1, y: y1),
        ])
        plus.closeSubpath()
        ctx.fill(plus, with: .color(Palette.control))

        let arms: [(PadButton, CGRect, CGFloat)] = [
            (.dpadUp, CGRect(x: x1, y: y0, width: w, height: l), 0),
            (.dpadDown, CGRect(x: x1, y: y2, width: w, height: l), CGFloat.pi),
            (.dpadLeft, CGRect(x: x0, y: y1, width: l, height: w), -CGFloat.pi / 2),
            (.dpadRight, CGRect(x: x2, y: y1, width: l, height: w), CGFloat.pi / 2),
        ]
        for (button, rect, angle) in arms {
            let pressed = state[button]
            if pressed {
                fillGlow(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3), color: accent, glow: true, &ctx)
            }
            arrow(at: CGPoint(x: rect.midX, y: rect.midY), angle: angle,
                  color: pressed ? Palette.onAccent : Palette.dimLabel, &ctx)
        }
        ctx.stroke(plus, with: .color(Palette.controlStroke), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
    }

    private func drawFaceButtons(_ ctx: inout GraphicsContext) {
        let c = layout.face
        let distance: CGFloat = 23
        let radius: CGFloat = 11.5
        let items: [(PadButton, CGPoint)] = [
            (.north, CGPoint(x: c.x, y: c.y - distance)),
            (.south, CGPoint(x: c.x, y: c.y + distance)),
            (.west, CGPoint(x: c.x - distance, y: c.y)),
            (.east, CGPoint(x: c.x + distance, y: c.y)),
        ]
        for (button, p) in items {
            let pressed = state[button]
            let tint = faceTint(button)
            let shape = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
            fillGlow(shape, color: pressed ? tint : Palette.control, glow: pressed, &ctx)
            ctx.stroke(shape, with: .color(pressed ? tint : Palette.controlStroke), lineWidth: 1.2)
            let glyphColor = pressed ? Palette.onAccent : (colored ? tint : Palette.label)
            faceGlyph(button, at: p, color: glyphColor, &ctx)
        }
    }

    private func drawStick(_ ctx: inout GraphicsContext, center c: CGPoint, value: CGPoint, button: PadButton) {
        let baseRadius: CGFloat = 26
        let capRadius: CGFloat = 16.5
        let travel: CGFloat = 11

        let base = Path(ellipseIn: CGRect(x: c.x - baseRadius, y: c.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2))
        ctx.fill(base, with: .color(Palette.well))
        ctx.stroke(base, with: .color(Palette.controlStroke), lineWidth: 1.2)

        let dx = clamp(value.x, -1, 1)
        let dy = clamp(value.y, -1, 1)
        let magnitude = min((dx * dx + dy * dy).squareRoot(), 1)

        if magnitude > 0.08 {
            var line = Path()
            line.move(to: c)
            line.addLine(to: CGPoint(x: c.x + dx * (baseRadius - 3), y: c.y - dy * (baseRadius - 3)))
            ctx.stroke(line, with: .color(accent.opacity(0.45 + 0.55 * Double(magnitude))),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        let pressed = state[button]
        let capCenter = CGPoint(x: c.x + dx * travel, y: c.y - dy * travel)
        let cap = Path(ellipseIn: CGRect(x: capCenter.x - capRadius, y: capCenter.y - capRadius, width: capRadius * 2, height: capRadius * 2))
        let capShading: GraphicsContext.Shading = pressed
            ? .color(accent)
            : .radialGradient(Gradient(colors: [Color(white: 0.38), Color(white: 0.20)]),
                              center: CGPoint(x: capCenter.x - 4, y: capCenter.y - 5),
                              startRadius: 0,
                              endRadius: capRadius * 1.4)
        let shadowColor = pressed ? accent : Color.black.opacity(0.6)
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: shadowColor, radius: pressed ? 8 : 4))
            layer.fill(cap, with: capShading)
        }
        ctx.stroke(cap, with: .color(pressed ? accent : Color.white.opacity(0.18)), lineWidth: 1.2)

        let grip = Path(ellipseIn: CGRect(x: capCenter.x - capRadius + 5, y: capCenter.y - capRadius + 5,
                                          width: (capRadius - 5) * 2, height: (capRadius - 5) * 2))
        ctx.stroke(grip, with: .color(pressed ? Color.black.opacity(0.3) : Color.white.opacity(0.08)), lineWidth: 1)
    }

    // MARK: Helpers

    private func fillGlow(_ path: Path, color: Color, glow: Bool, _ ctx: inout GraphicsContext) {
        if glow {
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.9), radius: 7))
                layer.fill(path, with: .color(color))
            }
        } else {
            ctx.fill(path, with: .color(color))
        }
    }

    private func text(_ string: String, at point: CGPoint, size: CGFloat, color: Color, _ ctx: inout GraphicsContext) {
        var resolved = ctx.resolve(Text(string).font(.system(size: size, weight: .bold, design: .rounded)))
        resolved.shading = .color(color)
        ctx.draw(resolved, at: point, anchor: .center)
    }

    private func symbol(_ name: String, at point: CGPoint, size: CGFloat, color: Color, _ ctx: inout GraphicsContext) {
        var resolved = ctx.resolve(Text(Image(systemName: name)).font(.system(size: size, weight: .bold)))
        resolved.shading = .color(color)
        ctx.draw(resolved, at: point, anchor: .center)
    }

    private func arrow(at point: CGPoint, angle: CGFloat, color: Color, _ ctx: inout GraphicsContext) {
        let s: CGFloat = 4
        let transform = CGAffineTransform(translationX: point.x, y: point.y).rotated(by: angle)
        let corners = [CGPoint(x: 0, y: -s), CGPoint(x: s, y: s * 0.7), CGPoint(x: -s, y: s * 0.7)]
        var path = Path()
        path.addLines(corners.map { $0.applying(transform) })
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    private func faceGlyph(_ button: PadButton, at p: CGPoint, color: Color, _ ctx: inout GraphicsContext) {
        guard skin == .playstation else {
            text(button.label(for: skin), at: p, size: 12, color: color, &ctx)
            return
        }
        var path = Path()
        switch button {
        case .south:
            path.move(to: CGPoint(x: p.x - 4.5, y: p.y - 4.5))
            path.addLine(to: CGPoint(x: p.x + 4.5, y: p.y + 4.5))
            path.move(to: CGPoint(x: p.x + 4.5, y: p.y - 4.5))
            path.addLine(to: CGPoint(x: p.x - 4.5, y: p.y + 4.5))
        case .east:
            path.addEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
        case .west:
            path.addRect(CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
        case .north:
            path.move(to: CGPoint(x: p.x, y: p.y - 6.3))
            path.addLine(to: CGPoint(x: p.x + 5.5, y: p.y + 3.2))
            path.addLine(to: CGPoint(x: p.x - 5.5, y: p.y + 3.2))
            path.closeSubpath()
        default:
            break
        }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    private func faceTint(_ button: PadButton) -> Color {
        guard colored else { return accent }
        let green = Color(red: 0.38, green: 0.78, blue: 0.29)
        let red = Color(red: 0.93, green: 0.28, blue: 0.25)
        let blue = Color(red: 0.22, green: 0.56, blue: 0.96)
        let yellow = Color(red: 0.98, green: 0.78, blue: 0.20)
        switch (skin, button) {
        case (.xbox, .south): return green
        case (.xbox, .east): return red
        case (.xbox, .west): return blue
        case (.xbox, .north): return yellow
        case (.playstation, .south): return Color(red: 0.47, green: 0.64, blue: 0.98)
        case (.playstation, .east): return Color(red: 0.96, green: 0.38, blue: 0.44)
        case (.playstation, .west): return Color(red: 0.90, green: 0.55, blue: 0.84)
        case (.playstation, .north): return Color(red: 0.27, green: 0.83, blue: 0.71)
        case (.nintendo, .south): return yellow
        case (.nintendo, .east): return red
        case (.nintendo, .west): return green
        case (.nintendo, .north): return blue
        default: return accent
        }
    }
}
