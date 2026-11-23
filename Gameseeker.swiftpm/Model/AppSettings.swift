import SwiftUI

enum SkinPreference: String, CaseIterable, Identifiable {
    case auto, xbox, playstation, nintendo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Otomatik"
        case .xbox: return "Xbox"
        case .playstation: return "PlayStation"
        case .nintendo: return "Nintendo"
        }
    }

    func resolve(_ kind: ControllerKind) -> PadSkin {
        switch self {
        case .auto: return kind.preferredSkin
        case .xbox: return .xbox
        case .playstation: return .playstation
        case .nintendo: return .nintendo
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case cyan, lime, violet, orange, pink, gold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: return "Camgöbeği"
        case .lime: return "Limon"
        case .violet: return "Mor"
        case .orange: return "Turuncu"
        case .pink: return "Pembe"
        case .gold: return "Altın"
        }
    }

    var color: Color {
        switch self {
        case .cyan: return Color(red: 0.20, green: 0.85, blue: 0.95)
        case .lime: return Color(red: 0.62, green: 0.95, blue: 0.25)
        case .violet: return Color(red: 0.66, green: 0.50, blue: 1.00)
        case .orange: return Color(red: 1.00, green: 0.58, blue: 0.20)
        case .pink: return Color(red: 1.00, green: 0.40, blue: 0.70)
        case .gold: return Color(red: 1.00, green: 0.82, blue: 0.25)
        }
    }
}

enum ViewerBackground: String, CaseIterable, Identifiable {
    case dark, black, chromaGreen, chromaBlue, chromaMagenta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Koyu"
        case .black: return "Siyah"
        case .chromaGreen: return "Yeşil perde"
        case .chromaBlue: return "Mavi perde"
        case .chromaMagenta: return "Magenta perde"
        }
    }

    var color: Color {
        switch self {
        case .dark: return Color(red: 0.07, green: 0.08, blue: 0.11)
        case .black: return .black
        case .chromaGreen: return Color(red: 0.0, green: 0.69, blue: 0.25)
        case .chromaBlue: return Color(red: 0.0, green: 0.28, blue: 0.73)
        case .chromaMagenta: return Color(red: 1.0, green: 0.0, blue: 1.0)
        }
    }
}

enum CloudService: String, CaseIterable, Identifiable {
    case xboxCloud, fortniteXbox, geforceNow, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xboxCloud: return "Xbox Cloud Gaming"
        case .fortniteXbox: return "Fortnite (Xbox Cloud)"
        case .geforceNow: return "GeForce NOW"
        case .custom: return "Özel adres"
        }
    }

    var detail: String {
        switch self {
        case .xboxCloud: return "xbox.com/play — Microsoft hesabıyla giriş. Fortnite gibi ücretsiz oyunlar Game Pass gerektirmez."
        case .fortniteXbox: return "Doğrudan Fortnite'ın Xbox Cloud Gaming sayfasını açar."
        case .geforceNow: return "play.geforcenow.com — NVIDIA hesabıyla giriş."
        case .custom: return "Gamepad API kullanan herhangi bir web oyunu veya bulut servisi."
        }
    }

    var url: URL? {
        switch self {
        case .xboxCloud: return URL(string: "https://www.xbox.com/play")
        case .fortniteXbox: return URL(string: "https://www.xbox.com/play/games/fortnite/BT5P2X999VH2")
        case .geforceNow: return URL(string: "https://play.geforcenow.com")
        case .custom: return nil
        }
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    // Appearance
    @Published var skin: SkinPreference { didSet { save(skin.rawValue, .skin) } }
    @Published var accent: AccentChoice { didSet { save(accent.rawValue, .accent) } }
    @Published var coloredFaceButtons: Bool { didSet { save(coloredFaceButtons, .coloredFaceButtons) } }
    @Published var showBody: Bool { didSet { save(showBody, .showBody) } }

    // In-game overlay
    @Published var overlayOpacity: Double { didSet { save(overlayOpacity, .overlayOpacity) } }
    @Published var overlayWidth: Double { didSet { save(overlayWidth, .overlayWidth) } }
    /// Overlay centre, as a fraction of the screen size.
    @Published var overlayX: Double { didSet { save(overlayX, .overlayX) } }
    @Published var overlayY: Double { didSet { save(overlayY, .overlayY) } }
    @Published var overlayPanel: Bool { didSet { save(overlayPanel, .overlayPanel) } }
    @Published var overlayHistory: Bool { didSet { save(overlayHistory, .overlayHistory) } }

    // Viewer mode
    @Published var viewerBackground: ViewerBackground { didSet { save(viewerBackground.rawValue, .viewerBackground) } }
    @Published var viewerHistory: Bool { didSet { save(viewerHistory, .viewerHistory) } }
    @Published var viewerReadout: Bool { didSet { save(viewerReadout, .viewerReadout) } }

    // Cloud gaming
    @Published var service: CloudService { didSet { save(service.rawValue, .service) } }
    @Published var customURL: String { didSet { save(customURL, .customURL) } }
    @Published var nativeBridge: Bool { didSet { save(nativeBridge, .nativeBridge) } }

    static let overlayWidthRange: ClosedRange<Double> = 160...720
    static let defaultOverlayWidth: Double = 300
    static let defaultOverlayX: Double = 0.5
    static let defaultOverlayY: Double = 0.80

    init() {
        let d = UserDefaults.standard
        func string(_ key: Key) -> String { d.string(forKey: key.rawValue) ?? "" }
        func bool(_ key: Key, _ fallback: Bool) -> Bool { d.object(forKey: key.rawValue) as? Bool ?? fallback }
        func double(_ key: Key, _ fallback: Double) -> Double { d.object(forKey: key.rawValue) as? Double ?? fallback }

        skin = SkinPreference(rawValue: string(.skin)) ?? .auto
        accent = AccentChoice(rawValue: string(.accent)) ?? .cyan
        coloredFaceButtons = bool(.coloredFaceButtons, true)
        showBody = bool(.showBody, true)

        overlayOpacity = double(.overlayOpacity, 0.85)
        overlayWidth = double(.overlayWidth, Self.defaultOverlayWidth)
        overlayX = double(.overlayX, Self.defaultOverlayX)
        overlayY = double(.overlayY, Self.defaultOverlayY)
        overlayPanel = bool(.overlayPanel, false)
        overlayHistory = bool(.overlayHistory, true)

        viewerBackground = ViewerBackground(rawValue: string(.viewerBackground)) ?? .dark
        viewerHistory = bool(.viewerHistory, true)
        viewerReadout = bool(.viewerReadout, false)

        service = CloudService(rawValue: string(.service)) ?? .xboxCloud
        customURL = string(.customURL)
        nativeBridge = bool(.nativeBridge, true)
    }

    /// The address the play screen should open, or `nil` when the custom address is empty/invalid.
    var playURL: URL? {
        guard service == .custom else { return service.url }
        var text = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }

    func resolvedSkin(for kind: ControllerKind) -> PadSkin {
        skin.resolve(kind)
    }

    func resetOverlayLayout() {
        overlayWidth = Self.defaultOverlayWidth
        overlayX = Self.defaultOverlayX
        overlayY = Self.defaultOverlayY
        overlayOpacity = 0.85
    }

    private func save(_ value: Any, _ key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private enum Key: String {
        case skin, accent, coloredFaceButtons, showBody
        case overlayOpacity, overlayWidth, overlayX, overlayY, overlayPanel, overlayHistory
        case viewerBackground, viewerHistory, viewerReadout
        case service, customURL, nativeBridge
    }
}
