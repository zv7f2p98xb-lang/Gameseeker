import SwiftUI

struct CardBackground: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

struct AppBackground: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.10),
                                    Color(red: 0.02, green: 0.02, blue: 0.04)],
                           startPoint: .top,
                           endPoint: .bottom)
            RadialGradient(colors: [settings.accent.color.opacity(0.16), .clear],
                           center: .topLeading,
                           startRadius: 0,
                           endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct BatteryBadge: View {
    let level: Float
    let charging: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(Int((level * 100).rounded()))%")
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(level < 0.2 && !charging ? Color.red : Color.secondary)
        .accessibilityLabel("Pil yüzde \(Int((level * 100).rounded()))")
    }

    private var symbol: String {
        if charging { return "battery.100.bolt" }
        switch level {
        case ..<0.13: return "battery.0"
        case ..<0.38: return "battery.25"
        case ..<0.63: return "battery.50"
        case ..<0.88: return "battery.75"
        default: return "battery.100"
        }
    }
}

struct ControllerStatusPill: View {
    @Environment(ControllerManager.self) private var controllers

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(controllers.isConnected ? Color.green : Color.red)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(controllers.isConnected ? controllers.controllerName : "Kol bağlı değil")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if controllers.isConnected {
                    Text(controllers.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let level = controllers.batteryLevel {
                BatteryBadge(level: level, charging: controllers.isCharging)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}

/// Explains, inside the app, why the overlay can't sit on top of the native Fortnite app.
struct LimitationNote: View {
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text("iPadOS, bir uygulamanın başka bir uygulamanın (ör. App Store'dan indirilen Fortnite) üstüne çizim yapmasına izin vermiyor.")
                Text("Apple'ın GameController çerçevesi, kol girdisini yalnızca ön plandaki uygulamaya iletir. Arka plandaki bir uygulama, sen başka bir oyundayken tuş basışlarını okuyamaz. Apple, bu ayarın iOS ve iPadOS'ta yok sayıldığını belgeliyor.")
                Text("Bu yüzden Gameseeker oyunu kendi içinde açar (Xbox Cloud Gaming, GeForce NOW ya da Gamepad API kullanan herhangi bir web oyunu) ve tuşlarını oyunun hemen üstünde gösterir. iPad'in ekran kaydı da overlay'i kaydeder.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        } label: {
            Label("Neden doğrudan Fortnite uygulamasının üstünde çalışmıyor?", systemImage: "questionmark.circle")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .card()
    }
}
