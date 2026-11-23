import SwiftUI

/// Full-screen "gamepad viewer": just the controller on a solid / chroma-key background.
struct ViewerView: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            settings.viewerBackground.color
                .ignoresSafeArea()

            VStack(spacing: 28) {
                LiveGamepad()
                    .frame(maxWidth: 980)
                if settings.viewerHistory {
                    LiveHistory()
                }
                if settings.viewerReadout {
                    LiveReadout()
                }
            }
            .padding(32)

            if !controllers.isConnected {
                VStack {
                    Spacer()
                    Label("Kol bağlı değil — Ayarlar › Bluetooth", systemImage: "gamecontroller")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 40)
                }
                .allowsHitTesting(false)
            }

            if controlsVisible {
                controls
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible.toggle()
            }
            if controlsVisible {
                scheduleHide()
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            scheduleHide()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            hideTask?.cancel()
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Kapat")

                Spacer()

                Menu {
                    Picker("Arka plan", selection: $settings.viewerBackground) {
                        ForEach(ViewerBackground.allCases) { background in
                            Text(background.title).tag(background)
                        }
                    }
                    Picker("Kol tipi", selection: $settings.skin) {
                        ForEach(SkinPreference.allCases) { skin in
                            Text(skin.title).tag(skin)
                        }
                    }
                    Toggle("Tuş geçmişi", isOn: $settings.viewerHistory)
                    Toggle("Eksen değerleri", isOn: $settings.viewerReadout)
                    Toggle("Kol gövdesi", isOn: $settings.showBody)
                } label: {
                    Label("Görünüm", systemImage: "paintpalette")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            Spacer()
            Text("Kontrolleri göstermek ya da gizlemek için ekrana dokun")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(20)
        .tint(.white)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                controlsVisible = false
            }
        }
    }
}
