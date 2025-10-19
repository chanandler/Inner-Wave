import SwiftUI
import AVFoundation

@Observable
final class SettingsStore {
    @AppStorage("stepDuration") var stepDuration: Double = 4 // default seconds per step unit
    @AppStorage("pauseDuration") var pauseDuration: Double = 2
    @AppStorage("loopPractice") var loopPractice: Bool = true
    @AppStorage("roundsPerRest") var roundsPerRest: Int = 3
    @AppStorage("soundCuesEnabled") var soundCuesEnabled: Bool = true
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
}

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            Section("Timing") {
                Stepper(value: bindingDouble($settings.stepDuration), in: 2...10, step: 1) {
                    HStack {
                        Text("Step duration")
                        Spacer()
                        Text("\(Int(settings.stepDuration))s")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: bindingDouble($settings.pauseDuration), in: 0...6, step: 1) {
                    HStack {
                        Text("Pause duration")
                        Spacer()
                        Text("\(Int(settings.pauseDuration))s")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Loop practice", isOn: $settings.loopPractice)
                Stepper(value: $settings.roundsPerRest, in: 1...10) {
                    HStack {
                        Text("Rounds before Rest screen")
                        Spacer()
                        Text("\(settings.roundsPerRest)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Cues") {
                Toggle("Sound cues", isOn: $settings.soundCuesEnabled)
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            }
        }
        .navigationTitle("Settings")
    }

    // Helper to satisfy Stepper with Double in a nicer API
    private func bindingDouble(_ appStorage: AppStorage<Double>) -> Binding<Double> {
        Binding(get: { appStorage.wrappedValue }, set: { appStorage.wrappedValue = $0 })
    }
}

// Simple bell player
enum SoundCuePlayer {
    static var player: AVAudioPlayer?
    static func playBell(enabled: Bool) {
        guard enabled else { return }
        // Use system sound if bundled asset not available; generate a short tone.
        // Here we synthesize a very short silent audio if resource missing to avoid crash.
        if let url = Bundle.main.url(forResource: "bell", withExtension: "wav") {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                player?.play()
            } catch {
                // ignore
            }
        }
    }
}
