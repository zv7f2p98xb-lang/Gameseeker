import SwiftUI

/// Runs a cloud / web game inside the app and draws the live gamepad overlay on top of it.
struct PlayView: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var overlayVisible = true
    @State private var commands = WebCommands()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let url = settings.playURL {
                GameWebView(url: url,
                            bridgeEnabled: settings.nativeBridge,
                            controllers: controllers,
                            commands: commands)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView("Adres geçersiz",
                                       systemImage: "link",
                                       description: Text("Ayarlar › Bulut oyun bölümünden geçerli bir adres gir."))
            }

            if overlayVisible {
                OverlayLayer(editing: editing)
                    .ignoresSafeArea()
            }

            ConnectionToast()

            VStack {
                HStack {
                    controlMenu
                    Spacer()
                }
                Spacer()
            }
            .padding(12)

            if editing {
                EditPanel {
                    withAnimation(.snappy) { editing = false }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var controlMenu: some View {
        Menu {
            Button {
                withAnimation(.snappy) {
                    overlayVisible = true
                    editing = true
                }
            } label: {
                Label("Overlay'i düzenle", systemImage: "slider.horizontal.3")
            }
            Button {
                overlayVisible.toggle()
            } label: {
                Label(overlayVisible ? "Overlay'i gizle" : "Overlay'i göster",
                      systemImage: overlayVisible ? "eye.slash" : "eye")
            }
            Divider()
            Button {
                commands.goBack()
            } label: {
                Label("Geri", systemImage: "chevron.backward")
            }
            Button {
                commands.reload()
            } label: {
                Label("Yenile", systemImage: "arrow.clockwise")
            }
            Button {
                commands.goHome()
            } label: {
                Label("Servis ana sayfası", systemImage: "house")
            }
            Divider()
            Button(role: .destructive) {
                dismiss()
            } label: {
                Label("Oyundan çık", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .opacity(0.6)
        }
        .accessibilityLabel("Oyun menüsü")
    }
}

/// Positions the overlay; in edit mode it can be dragged and pinched.
/// Outside edit mode it ignores touches so the game underneath gets them.
struct OverlayLayer: View {
    @EnvironmentObject private var settings: AppSettings
    let editing: Bool
    @State private var drag: CGSize = .zero
    @State private var pinch: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let width = min(CGFloat(settings.overlayWidth) * pinch, size.width)
            let center = CGPoint(x: CGFloat(settings.overlayX) * size.width + drag.width,
                                 y: CGFloat(settings.overlayY) * size.height + drag.height)

            OverlayContent()
                .frame(width: width)
                .overlay {
                    if editing {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(settings.accent.color, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .padding(-8)
                    }
                }
                .opacity(settings.overlayOpacity)
                .contentShape(Rectangle())
                .position(center)
                .gesture(dragGesture(in: size).simultaneously(with: pinchGesture),
                         including: editing ? .all : .none)
        }
        .allowsHitTesting(editing)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                drag = value.translation
            }
            .onEnded { value in
                guard size.width > 0, size.height > 0 else { return }
                let x = (settings.overlayX * Double(size.width) + Double(value.translation.width)) / Double(size.width)
                let y = (settings.overlayY * Double(size.height) + Double(value.translation.height)) / Double(size.height)
                settings.overlayX = clamp(x, 0.03, 0.97)
                settings.overlayY = clamp(y, 0.03, 0.97)
                drag = .zero
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinch = value.magnification
            }
            .onEnded { value in
                let range = AppSettings.overlayWidthRange
                settings.overlayWidth = clamp(settings.overlayWidth * Double(value.magnification),
                                              range.lowerBound, range.upperBound)
                pinch = 1
            }
    }
}

/// The overlay itself: controller drawing, optional history strip and backing panel.
struct OverlayContent: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 6) {
            LiveGamepad()
            if settings.overlayHistory {
                LiveHistory(compact: true)
            }
        }
        .padding(settings.overlayPanel ? 12 : 0)
        .background {
            if settings.overlayPanel {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            }
        }
    }
}

struct EditPanel: View {
    @EnvironmentObject private var settings: AppSettings
    let done: () -> Void

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Overlay'i sürükle, iki parmakla büyüt / küçült")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .frame(width: 24)
                    Slider(value: $settings.overlayOpacity, in: 0.2...1)
                    Text("%\(Int(settings.overlayOpacity * 100))")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 24)
                    Slider(value: $settings.overlayWidth, in: AppSettings.overlayWidthRange)
                    Text("\(Int(settings.overlayWidth))")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                Toggle("Koyu arka panel", isOn: $settings.overlayPanel)
                Toggle("Son basılan tuşlar", isOn: $settings.overlayHistory)
                HStack {
                    Button("Sıfırla", role: .destructive) {
                        settings.resetOverlayLayout()
                    }
                    Spacer()
                    Button("Bitti", action: done)
                        .buttonStyle(.borderedProminent)
                }
            }
            .font(.callout)
            .padding(18)
            .frame(maxWidth: 440)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 60)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}

struct ConnectionToast: View {
    @Environment(ControllerManager.self) private var controllers

    var body: some View {
        VStack {
            if !controllers.isConnected {
                Label("Kol bağlı değil", systemImage: "gamecontroller")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 14)
        .allowsHitTesting(false)
        .animation(.snappy, value: controllers.isConnected)
    }
}
