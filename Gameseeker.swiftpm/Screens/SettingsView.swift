import SwiftUI

struct SettingsView: View {
    @Environment(ControllerManager.self) private var controllers
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        LiveGamepad()
                            .frame(maxHeight: 220)
                        LiveHistory(compact: true)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white.opacity(0.04))
                } footer: {
                    Text(controllers.isConnected
                         ? "\(controllers.controllerName) bağlı. Tuşlara basarak önizlemeyi deneyebilirsin."
                         : "Kol bağlı değil. iPad Ayarlar › Bluetooth üzerinden eşleştir.")
                }

                Section("Görünüm") {
                    Picker("Kol tipi", selection: $settings.skin) {
                        ForEach(SkinPreference.allCases) { skin in
                            Text(skin.title).tag(skin)
                        }
                    }
                    Picker("Vurgu rengi", selection: $settings.accent) {
                        ForEach(AccentChoice.allCases) { accent in
                            Text(accent.title).tag(accent)
                        }
                    }
                    Toggle("Renkli yüz tuşları", isOn: $settings.coloredFaceButtons)
                    Toggle("Kol gövdesini göster", isOn: $settings.showBody)
                }

                Section {
                    sliderRow(title: "Opaklık",
                              value: $settings.overlayOpacity,
                              range: 0.2...1,
                              display: "%\(Int(settings.overlayOpacity * 100))")
                    sliderRow(title: "Genişlik",
                              value: $settings.overlayWidth,
                              range: AppSettings.overlayWidthRange,
                              display: "\(Int(settings.overlayWidth)) pt")
                    Toggle("Koyu arka panel", isOn: $settings.overlayPanel)
                    Toggle("Son basılan tuşlar", isOn: $settings.overlayHistory)
                    Button("Konum ve boyutu sıfırla") {
                        settings.resetOverlayLayout()
                    }
                } header: {
                    Text("Oyun içi overlay")
                } footer: {
                    Text("Oyun sırasında sol üstteki kol simgesine dokunup “Overlay'i düzenle” ile sürükleyip iki parmakla boyutlandırabilirsin.")
                }

                Section {
                    Picker("Servis", selection: $settings.service) {
                        ForEach(CloudService.allCases) { service in
                            Text(service.title).tag(service)
                        }
                    }
                    if settings.service == .custom {
                        TextField("https://…", text: $settings.customURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Yerel kol köprüsü", isOn: $settings.nativeBridge)
                } header: {
                    Text("Bulut oyun")
                } footer: {
                    Text("\(settings.service.detail)\n\nYerel kol köprüsü, kolunu oyuna doğrudan uygulamanın okuduğu değerlerle iletir; overlay ile oyun her zaman aynı şeyi görür. Oyun kolu algılamazsa kapatıp yeniden dene. Değişiklik bir sonraki oyun açılışında geçerli olur.")
                }

                Section("İzleyici modu") {
                    Picker("Arka plan", selection: $settings.viewerBackground) {
                        ForEach(ViewerBackground.allCases) { background in
                            Text(background.title).tag(background)
                        }
                    }
                    Toggle("Son basılan tuşlar", isOn: $settings.viewerHistory)
                    Toggle("Eksen değerleri", isOn: $settings.viewerReadout)
                }

                Section("Bilgi") {
                    Text("iPadOS, uygulamaların başka bir uygulamanın üstüne çizim yapmasına ve arka plandayken kol tuşlarını okumasına izin vermez. Bu nedenle overlay, oyun Gameseeker'ın içinde (bulut oyun ya da web oyunu olarak) açıldığında çalışır.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(display)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
