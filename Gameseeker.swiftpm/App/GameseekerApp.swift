import SwiftUI

@main
struct GameseekerApp: App {
    @State private var controllers = ControllerManager()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(controllers)
                .environmentObject(settings)
                .tint(settings.accent.color)
                .preferredColorScheme(.dark)
        }
    }
}
