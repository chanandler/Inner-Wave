import SwiftUI
import AVFoundation
import CoreHaptics
import UIKit

// MARK: - Data models

struct BreathStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let duration: TimeInterval
}

enum PracticeDifficulty: String {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var color: Color {
        switch self {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .advanced:     return .red
        }
    }
}

struct BreathPracticeModel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let intro: String
    let icon: String          // SF Symbol name
    let difficulty: PracticeDifficulty
    let estimatedMinutes: Int
    let steps: [BreathStep]
    let loop: Bool
}

// MARK: - Practice View

struct BreathPracticeView: View {
    let model: BreathPracticeModel

    @Environment(SettingsStore.self) private var settings
    @Environment(BreathingRhythm.self) private var rhythm
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.verticalSizeClass) private var vClass

    @State private var currentIndex: Int = 0
    @State private var remaining: TimeInterval = 0
    @State private var stepDuration: TimeInterval = 0
    @State private var running: Bool = false
    @State private var pulse = false

    @State private var hapticsEngine: CHHapticEngine? = nil
    @State private var completedRounds: Int = 0
    @State private var showingRest: Bool = false

    @State private var timerTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Title & intro
            VStack(spacing: 6) {
                Text(model.title)
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Text(model.intro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 12)

            // Step progress bar
            StepProgressBar(total: model.steps.count, current: currentIndex)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Round counter
            if settings.loopPractice && completedRounds > 0 {
                Text("Round \(completedRounds + 1)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
            }

            Spacer(minLength: 12)

            // Breathing pulse visual
            GeometryReader { proxy in
                let totalH = proxy.size.height
                let maxCap: CGFloat = vClass == .compact ? 280 : 380
                let baseDiameter = min(totalH * 0.85, maxCap)
                let stepColor = colorForStep(currentStep)

                ZStack {
                    // Outer glow
                    Circle()
                        .fill(stepColor.opacity(0.15))
                        .frame(width: baseDiameter * 1.15, height: baseDiameter * 1.15)
                        .blur(radius: 20)

                    // Animated breathing circle
                    Circle()
                        .fill(stepColor.opacity(0.3))
                        .overlay(Circle().stroke(stepColor.opacity(0.8), lineWidth: 2.5))
                        .frame(width: baseDiameter, height: baseDiameter)
                        .scaleEffect(pulse ? 1.1 : 0.9)
                        .animation(
                            running
                                ? .easeInOut(duration: stepDuration / 2).repeatForever(autoreverses: true)
                                : .easeInOut(duration: 0.3),
                            value: pulse
                        )
                        .onChange(of: running) { _, newValue in
                            pulse = newValue
                        }
                        .onChange(of: currentIndex) {
                            if running {
                                pulse = false
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(50))
                                    pulse = true
                                }
                            }
                        }

                    // Step label + countdown
                    VStack(spacing: 6) {
                        Text(currentStep.title)
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        if let s = currentStep.subtitle, !s.isEmpty {
                            Text(s)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                        }
                        Text(timeString(remaining))
                            .monospacedDigit()
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .frame(width: baseDiameter * 0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button { previous() } label: {
                    Label("Back", systemImage: "backward.fill")
                }
                .disabled(currentIndex == 0)

                Button { toggle() } label: {
                    Label(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.title3)
                        .padding(.horizontal, 12)
                }

                Button { next() } label: {
                    Label("Next", systemImage: "forward.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
        .sheet(isPresented: $showingRest) {
            RestView(dismiss: { showingRest = false })
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startStep(index: 0)
            prepareHaptics()
        }
        .onDisappear {
            cancelTimer()
            rhythm.isRunning = false
            setScreenAwake(false)
            recordSessionIfNeeded()
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { resetButton } }
    }

    // MARK: - Subviews

    private var resetButton: some View {
        Button("Reset") {
            recordSessionIfNeeded()
            completedRounds = 0
            startStep(index: 0)
        }
        .disabled(currentIndex == 0 && remaining == stepDuration && !running && completedRounds == 0)
    }

    // MARK: - State helpers

    private var currentStep: BreathStep { model.steps[currentIndex] }

    private func startStep(index: Int) {
        cancelTimer()
        currentIndex = index
        let duration = adjustedDuration(for: model.steps[index])
        stepDuration = duration
        remaining = duration
        rhythm.currentDuration = duration
        if running { startAsyncTimer() }
        playCue()
    }

    private func toggle() {
        running.toggle()
        if running {
            pulse = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                pulse = true
            }
            rhythm.isRunning = true
            setScreenAwake(true)
            startAsyncTimer()
        } else {
            rhythm.isRunning = false
            setScreenAwake(false)
            cancelTimer()
            pulse = false
        }
    }

    private func startAsyncTimer() {
        cancelTimer()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                tick()
            }
        }
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        rhythm.isRunning = false
    }

    private func tick() {
        guard running else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            next()
        }
    }

    private func next() {
        let nextIndex = currentIndex + 1
        if nextIndex < model.steps.count {
            startStep(index: nextIndex)
        } else if settings.loopPractice {
            completedRounds += 1
            if completedRounds % settings.roundsPerRest == 0 {
                running = false
                cancelTimer()
                setScreenAwake(false)
                showingRest = true
            } else {
                startStep(index: 0)
            }
        } else {
            completedRounds += 1
            running = false
            cancelTimer()
            setScreenAwake(false)
            recordSessionIfNeeded()
        }
    }

    private func previous() {
        startStep(index: max(0, currentIndex - 1))
    }

    // MARK: - Session recording

    private func recordSessionIfNeeded() {
        guard completedRounds > 0 else { return }
        sessionStore.record(practiceName: model.title, roundsCompleted: completedRounds)
        completedRounds = 0
    }

    // MARK: - Utilities

    private func timeString(_ t: TimeInterval) -> String {
        let i = Int(max(0, t))
        return String(format: "%02d:%02d", i / 60, i % 60)
    }

    private func adjustedDuration(for step: BreathStep) -> TimeInterval {
        if step.title.localizedCaseInsensitiveContains("pause") ||
            step.title.localizedCaseInsensitiveContains("hold") {
            return settings.pauseDuration
        }
        if step.title.localizedCaseInsensitiveContains("inhale") ||
            step.title.localizedCaseInsensitiveContains("exhale") ||
            step.title.localizedCaseInsensitiveContains("mantra") ||
            step.title.localizedCaseInsensitiveContains("root") ||
            step.title.localizedCaseInsensitiveContains("sacral") ||
            step.title.localizedCaseInsensitiveContains("solar") ||
            step.title.localizedCaseInsensitiveContains("heart") ||
            step.title.localizedCaseInsensitiveContains("throat") ||
            step.title.localizedCaseInsensitiveContains("third eye") ||
            step.title.localizedCaseInsensitiveContains("crown") {
            return settings.stepDuration
        }
        return step.duration
    }

    private func colorForStep(_ step: BreathStep) -> Color {
        let t = step.title.lowercased()
        if t.contains("inhale") || t.contains("root") || t.contains("sacral") ||
            t.contains("solar") || t.contains("heart") { return .blue }
        if t.contains("exhale") { return .teal }
        if t.contains("pause") || t.contains("hold") { return .purple }
        if t.contains("mantra") { return .indigo }
        if t.contains("throat") { return .cyan }
        if t.contains("third eye") { return .indigo }
        if t.contains("crown") { return .purple }
        return .mint
    }

    private func setScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    // MARK: - Haptics & sound

    private func playCue() {
        SoundCuePlayer.playBell(enabled: settings.soundCuesEnabled)
        triggerHaptic(enabled: settings.hapticsEnabled)
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticsEngine = try CHHapticEngine()
            try hapticsEngine?.start()
        } catch { }
    }

    private func triggerHaptic(enabled: Bool) {
        guard enabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let events = [CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0)]
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticsEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch { }
    }
}

// MARK: - Step Progress Bar

private struct StepProgressBar: View {
    let total: Int
    let current: Int

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let segW = (proxy.size.width - spacing * CGFloat(total - 1)) / CGFloat(total)
            HStack(spacing: spacing) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= current ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: segW, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Rest Screen

private struct RestView: View {
    var dismiss: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            Text("Rest in Stillness")
                .font(.title).bold()
            Text("Release visualization and rest. Tap Continue when you're ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Continue") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - Predefined Models

extension BreathPracticeModel {

    static let allPractices: [BreathPracticeModel] = [
        .anxietyReduction,
        .chakraActivation,
        .boxBreathing,
        .breathing478
    ]

    // MARK: Anxiety Reduction
    static let anxietyReduction: BreathPracticeModel = {
        let steps: [BreathStep] = [
            BreathStep(title: "Inhale – Belly",  subtitle: "Let the belly rise.", duration: 4),
            BreathStep(title: "Inhale – Ribs",   subtitle: "Let the ribs expand sideways.", duration: 4),
            BreathStep(title: "Inhale – Chest",  subtitle: "Let breath rise to chest and collarbones.", duration: 4),
            BreathStep(title: "Pause",            subtitle: "Hold gently.", duration: 2),
            BreathStep(title: "Exhale – Chest",  subtitle: "Soften the chest.", duration: 4),
            BreathStep(title: "Exhale – Ribs",   subtitle: "Soften the ribs.", duration: 4),
            BreathStep(title: "Exhale – Belly",  subtitle: "Soften the belly.", duration: 4),
            BreathStep(title: "Pause",            subtitle: "Rest.", duration: 2),
            BreathStep(title: "Mantra – Inhale", subtitle: "I am calm and centered.", duration: 4),
            BreathStep(title: "Mantra – Exhale", subtitle: "I release tension and fear.", duration: 4)
        ]
        return BreathPracticeModel(
            title: "Anxiety Reduction",
            description: "Three-part breath with gentle pauses to calm the nervous system.",
            intro: "Sit or lie comfortably. One hand on belly, one on chest. Breathe through the nose.",
            icon: "waveform.path.ecg",
            difficulty: .beginner,
            estimatedMinutes: 5,
            steps: steps,
            loop: true
        )
    }()

    // MARK: Chakra Activation
    static let chakraActivation: BreathPracticeModel = {
        var steps: [BreathStep] = []
        let chakraPrompts: [(String, String)] = [
            ("Root – Muladhara",       "Inhale, feel stability. 'I am grounded.'"),
            ("Sacral – Svadhisthana",  "Flow with life. 'I flow with life.'"),
            ("Solar Plexus – Manipura","Feel warmth. 'I am strong and purposeful.'"),
            ("Heart – Anahata",        "Expand compassion. 'I open to compassion.'"),
            ("Throat – Vishuddha",     "Open communication. 'I speak truthfully.'"),
            ("Third Eye – Ajna",       "Clarity of vision. 'I see with clarity.'"),
            ("Crown – Sahasrara",      "Connection. 'I am connected to all.'")
        ]
        for (title, sub) in chakraPrompts {
            steps.append(BreathStep(title: title, subtitle: sub, duration: 4))
        }
        for (title, sub) in chakraPrompts.reversed() {
            steps.append(BreathStep(title: title, subtitle: "Exhale down. " + sub, duration: 4))
        }
        steps.append(BreathStep(title: "Rest in stillness", subtitle: "Release and rest.", duration: 10))
        return BreathPracticeModel(
            title: "Chakra Activation",
            description: "Visualise light rising and falling through the seven energy centres.",
            intro: "Sit tall. Breathe through the nose. Let awareness rise through the chakras on the inhale and descend on the exhale.",
            icon: "circle.grid.cross.fill",
            difficulty: .intermediate,
            estimatedMinutes: 8,
            steps: steps,
            loop: true
        )
    }()

    // MARK: Box Breathing (4-4-4-4)
    static let boxBreathing: BreathPracticeModel = {
        let steps: [BreathStep] = [
            BreathStep(title: "Inhale",       subtitle: "Breathe in slowly.", duration: 4),
            BreathStep(title: "Hold – In",    subtitle: "Hold the breath at the top.", duration: 4),
            BreathStep(title: "Exhale",       subtitle: "Release slowly and completely.", duration: 4),
            BreathStep(title: "Hold – Out",   subtitle: "Rest at the bottom.", duration: 4)
        ]
        return BreathPracticeModel(
            title: "Box Breathing",
            description: "Equal-sided 4-4-4-4 pattern used by athletes and special forces to regulate stress.",
            intro: "Breathe through the nose. Keep each side of the box exactly equal.",
            icon: "square.dashed",
            difficulty: .beginner,
            estimatedMinutes: 4,
            steps: steps,
            loop: true
        )
    }()

    // MARK: 4-7-8 Breathing
    static let breathing478: BreathPracticeModel = {
        let steps: [BreathStep] = [
            BreathStep(title: "Inhale",  subtitle: "Breathe in through the nose for 4 counts.", duration: 4),
            BreathStep(title: "Hold",    subtitle: "Hold for 7 counts.", duration: 7),
            BreathStep(title: "Exhale",  subtitle: "Exhale fully through the mouth for 8 counts.", duration: 8)
        ]
        return BreathPracticeModel(
            title: "4-7-8 Breathing",
            description: "A natural tranquiliser — long exhale activates the parasympathetic response.",
            intro: "Inhale through the nose, exhale through the mouth with a gentle whoosh. Not recommended if you feel light-headed.",
            icon: "lungs.fill",
            difficulty: .intermediate,
            estimatedMinutes: 3,
            steps: steps,
            loop: true
        )
    }()
}

#Preview {
    NavigationStack { BreathPracticeView(model: .anxietyReduction) }
        .environment(SettingsStore())
        .environment(BreathingRhythm())
        .environment(SessionStore())
}
