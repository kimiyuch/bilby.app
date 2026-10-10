import AVFoundation
import SwiftUI

/// Warning time, the sound for each moment, spoken announcements and volume.
struct SoundSettings<Extra: View>: View {
    @Environment(TournamentStore.self) private var store
    @Environment(Alerts.self) private var alerts
    /// More sections at the end, such as updates on the Mac.
    @ViewBuilder var extra: () -> Extra

    private var settings: Binding<AppSettings> {
        Binding(get: { store.settings }, set: { store.settings = $0 })
    }

    var body: some View {
        Form {
            Section {
                Picker("Warn before the end", selection: settings.warningSeconds) {
                    Text("Off").tag(0)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                }
            } footer: {
                Text("The clock turns amber and the warning sound plays.")
            }

            Section("Sounds") {
                chimePicker("Warning", settings.warningSound)
                chimePicker("New level", settings.levelSound)
                chimePicker("Break starts", settings.breakStartSound)
                chimePicker("Break ends", settings.breakEndSound)
            }

            Section {
                Toggle("Announce levels and breaks", isOn: settings.announce)
                Picker("Voice", selection: settings.voice) {
                    Text("System default").tag(String?.none)
                    ForEach(SoundPlayer.voices, id: \.identifier) { voice in
                        Text(voiceName(voice)).tag(Optional(voice.identifier))
                    }
                }
                .disabled(!store.settings.announce)
                Button("Try the Voice") { alerts.previewVoice() }
                    .disabled(!store.settings.announce)
            } header: {
                Text("Voice")
            } footer: {
                Text("For example: \u{201C}Level 6. Blinds 150, 300, ante 300.\u{201D}")
            }

            Section("Volume") {
                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: settings.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .disabled(store.settings.muted)
                Toggle("Mute", isOn: settings.muted)
            }

            extra()
        }
        .formStyle(.grouped)
    }

    private func chimePicker(_ title: String, _ selection: Binding<Chime>) -> some View {
        HStack {
            Picker(title, selection: selection) {
                ForEach(Chime.allCases) { Text($0.title).tag($0) }
            }
            Button("Play", systemImage: "play.circle") { alerts.preview(selection.wrappedValue) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(selection.wrappedValue == .none)
        }
    }

    private func voiceName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality = switch voice.quality {
        case .premium: " (Premium)"
        case .enhanced: " (Enhanced)"
        default: ""
        }
        let region = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        return "\(voice.name)\(quality), \(region)"
    }
}

extension SoundSettings where Extra == EmptyView {
    init() { extra = { EmptyView() } }
}
