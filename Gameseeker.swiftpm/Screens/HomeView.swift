import SwiftUI

struct HomeView: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings
    @State private var showPlay = false
    @State private var showViewer = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                previewCard
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                    ActionCard(icon: "play.rectangle.fill",
                               title: "Oyna + Overlay",
                               subtitle: "\(settings.service.title) uygulamanın içinde açılır. Bastığın tuşlar oyunun üstünde anlık görünür.",
                               tint: settings.accent.color) {
                        showPlay = true
                    }
                    ActionCard(icon: "gamecontroller.fill",
                               title: "İzleyici modu",
                               subtitle: "Tam ekran gamepad görünümü. Yeşil perde arka planıyla kayıt ve yayına hazır.",
                               tint: .mint) {
                        showViewer = true
                    }
                    ActionCard(icon: "slider.horizontal.3",
                               title: "Ayarlar",
                               subtitle: "Kol tipi, renkler, overlay boyutu ve opaklığı, bulut oyun servisi.",
                               tint: .orange) {
                        showSettings = true
                    }
                }
                LimitationNote()
            }
            .padding(24)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackground())
        .fullScreenCover(isPresented: $showPlay) {
            PlayView()
                .environment(controllers)
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showViewer) {
            ViewerView()
                .environment(controllers)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(controllers)
                .environmentObject(settings)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gameseeker")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("Oyun kolu tuşlarını ekranda canlı göster")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            ControllerStatusPill()
        }
    }

    private var previewCard: some View {
        VStack(spacing: 14) {
            LiveGamepad()
                .frame(maxHeight: 340)
            LiveHistory()
            if !controllers.isConnected {
                Label("Kolunu Ayarlar › Bluetooth üzerinden eşleştir. Xbox, PlayStation (DualSense / DualShock 4), Switch Pro ve MFi kollar desteklenir.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }
}

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.15)))
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .card()
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .hoverEffect(.lift)
    }
}
