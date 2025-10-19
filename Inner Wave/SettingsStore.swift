import SwiftUI
import AVFoundation

// Keys for persistence
private enum SettingsKeys {
    static let stepDuration = "stepDuration"
    static let pauseDuration = "pauseDuration"
    static let loopPractice = "loopPractice"
    static let roundsPerRest = "roundsPerRest"
    static let soundCuesEnabled = "soundCuesEnabled"
    static let hapticsEnabled = "hapticsEnabled"
    static let mandalaTheme = "mandalaTheme"
}

enum MandalaTheme: String, CaseIterable, Identifiable, Sendable {
    case chakra
    case coolGlow
    case warmSunset
    case monochrome

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .chakra: return "Chakra Gradient"
        case .coolGlow: return "Cool Glow"
        case .warmSunset: return "Warm Sunset"
        case .monochrome: return "Monochrome"
        }
    }
}

@Observable
final class SettingsStore {
    // Plain stored properties observed by Swift's Observation framework
    var stepDuration: Double = 4 { didSet { save() } }
    var pauseDuration: Double = 2 { didSet { save() } }
    var loopPractice: Bool = true { didSet { save() } }
    var roundsPerRest: Int = 3 { didSet { save() } }
    var soundCuesEnabled: Bool = true { didSet { save() } }
    var hapticsEnabled: Bool = true { didSet { save() } }
    var mandalaTheme: MandalaTheme = .chakra { didSet { save() } }

    init() { load() }

    private func load() {
        let d = UserDefaults.standard
        if d.object(forKey: SettingsKeys.stepDuration) != nil { stepDuration = d.double(forKey: SettingsKeys.stepDuration) }
        if d.object(forKey: SettingsKeys.pauseDuration) != nil { pauseDuration = d.double(forKey: SettingsKeys.pauseDuration) }
        if d.object(forKey: SettingsKeys.loopPractice) != nil { loopPractice = d.bool(forKey: SettingsKeys.loopPractice) }
        if d.object(forKey: SettingsKeys.roundsPerRest) != nil { roundsPerRest = d.integer(forKey: SettingsKeys.roundsPerRest) }
        if d.object(forKey: SettingsKeys.soundCuesEnabled) != nil { soundCuesEnabled = d.bool(forKey: SettingsKeys.soundCuesEnabled) }
        if d.object(forKey: SettingsKeys.hapticsEnabled) != nil { hapticsEnabled = d.bool(forKey: SettingsKeys.hapticsEnabled) }
        if let raw = d.string(forKey: SettingsKeys.mandalaTheme), let t = MandalaTheme(rawValue: raw) { mandalaTheme = t }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(stepDuration, forKey: SettingsKeys.stepDuration)
        d.set(pauseDuration, forKey: SettingsKeys.pauseDuration)
        d.set(loopPractice, forKey: SettingsKeys.loopPractice)
        d.set(roundsPerRest, forKey: SettingsKeys.roundsPerRest)
        d.set(soundCuesEnabled, forKey: SettingsKeys.soundCuesEnabled)
        d.set(hapticsEnabled, forKey: SettingsKeys.hapticsEnabled)
        d.set(mandalaTheme.rawValue, forKey: SettingsKeys.mandalaTheme)
    }
}

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Timing") {
                Stepper(value: $settings.stepDuration, in: 2...10, step: 1) {
                    HStack {
                        Text("Step duration")
                        Spacer()
                        Text("\(Int(settings.stepDuration))s")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $settings.pauseDuration, in: 0...6, step: 1) {
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

            Section("Appearance") {
                Picker("Mandala theme", selection: $settings.mandalaTheme) {
                    ForEach(MandalaTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
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
}

// Simple bell player
enum SoundCuePlayer {
    static var player: AVAudioPlayer?
    static func playBell(enabled: Bool) {
        guard enabled else { return }
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
