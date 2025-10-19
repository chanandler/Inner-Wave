import SwiftUI
import AVFoundation
import CoreHaptics

struct BreathStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let duration: TimeInterval // seconds
}

struct BreathPracticeModel {
    let title: String
    let intro: String
    let steps: [BreathStep]
    let loop: Bool
}

struct BreathPracticeView: View {
    let model: BreathPracticeModel

    @Environment(SettingsStore.self) private var settings

    @State private var currentIndex: Int = 0
    @State private var remaining: TimeInterval = 0
    @State private var running: Bool = false
    @State private var timer: Timer? = nil
    @State private var pulse = false

    @State private var hapticsEngine: CHHapticEngine? = nil
    @State private var completedRounds: Int = 0
    @State private var showingRest: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text(model.title)
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
                .padding(.top)

            Text(model.intro)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer(minLength: 20)

            // Breathing pulse visual
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.0 : 0.85)
                    .animation(running ? .easeInOut(duration: adjustedDuration(for: currentStep)).repeatForever(autoreverses: true) : .default, value: pulse)
                    .onChange(of: running) { oldValue, newValue in
                        if newValue { pulse.toggle() } else { pulse = false }
                    }
                    .onChange(of: currentIndex) {
                        if running {
                            pulse.toggle()
                        }
                    }

                VStack(spacing: 6) {
                    Text(currentStep.title)
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)
                    if let s = currentStep.subtitle, !s.isEmpty {
                        Text(s)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Text(timeString(remaining))
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }

            Spacer()

            HStack(spacing: 24) {
                Button {
                    previous()
                } label: {
                    Label("Back", systemImage: "backward.fill")
                }
                .disabled(currentIndex == 0)

                Button {
                    toggle()
                } label: {
                    Label(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.title3)
                        .padding(.horizontal, 12)
                }

                Button {
                    next()
                } label: {
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
        .onDisappear { stopTimer() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { resetButton } }
    }

    private var resetButton: some View {
        Button("Reset") { startStep(index: 0) }
            .disabled(currentIndex == 0 && remaining == currentStep.duration && !running)
    }

    private var currentStep: BreathStep { model.steps[currentIndex] }

    private func startStep(index: Int) {
        stopTimer()
        currentIndex = index
        remaining = adjustedDuration(for: currentStep)
        if running { startTimer() }
        playCue()
    }

    private func toggle() {
        running.toggle()
        if running {
            startTimer()
            pulse.toggle()
        } else {
            stopTimer()
            pulse = false
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard running else { return }
        if remaining > 0 {
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
                stopTimer()
                showingRest = true
            } else {
                startStep(index: 0)
            }
        } else {
            running = false
            stopTimer()
        }
    }

    private func previous() {
        let prevIndex = max(0, currentIndex - 1)
        startStep(index: prevIndex)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let i = Int(max(0, t))
        return String(format: "%02d:%02d", i / 60, i % 60)
    }

    private func adjustedDuration(for step: BreathStep) -> TimeInterval {
        // Map canonical durations (4s inhale/exhale/mantra/chakra segments, 2s pauses) to fixed or settings durations
        if step.title.localizedCaseInsensitiveContains("pause") { return settings.pauseDuration }
        if step.title.localizedCaseInsensitiveContains("Inhale") ||
            step.title.localizedCaseInsensitiveContains("Exhale") ||
            step.title.localizedCaseInsensitiveContains("Mantra") ||
            step.title.localizedCaseInsensitiveContains("Root") ||
            step.title.localizedCaseInsensitiveContains("Sacral") ||
            step.title.localizedCaseInsensitiveContains("Solar") ||
            step.title.localizedCaseInsensitiveContains("Heart") ||
            step.title.localizedCaseInsensitiveContains("Throat") ||
            step.title.localizedCaseInsensitiveContains("Third Eye") ||
            step.title.localizedCaseInsensitiveContains("Crown") {
            return 4.0
        }
        return step.duration
    }

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

private struct RestView: View {
    var dismiss: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Rest in Stillness").font(.title).bold()
            Text("Release visualization and rest. Tap Continue when ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Button("Continue") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - Predefined Models
extension BreathPracticeModel {
    // Chakra activation: up through 7 chakras on inhale, down on exhale.
    // We'll provide one guided round with prompts, and suggest repeating.
    static let chakraActivation: BreathPracticeModel = {
        var steps: [BreathStep] = []
        let chakraPrompts: [(String, String)] = [
            ("Root – Muladhara", "Inhale, feel stability. ‘I am grounded.’"),
            ("Sacral – Svadhisthana", "Flow with life. ‘I flow with life.’"),
            ("Solar Plexus – Manipura", "Feel warmth. ‘I am strong and purposeful.’"),
            ("Heart – Anahata", "Expand compassion. ‘I open to compassion.’"),
            ("Throat – Vishuddha", "Open communication. ‘I speak truthfully and listen deeply.’"),
            ("Third Eye – Ajna", "Clarity of vision. ‘I see with clarity.’"),
            ("Crown – Sahasrara", "Connection. ‘I am connected to all.’")
        ]
        // Inhale ascending
        for (title, sub) in chakraPrompts {
            steps.append(BreathStep(title: title, subtitle: sub, duration: 4))
        }
        // Exhale descending
        for (title, sub) in chakraPrompts.reversed() {
            steps.append(BreathStep(title: title, subtitle: "Exhale down. " + sub, duration: 4))
        }
        // Rest
        steps.append(BreathStep(title: "Rest in stillness", subtitle: "Release visualization and rest.", duration: 10))

        return BreathPracticeModel(
            title: "Chakra Activation",
            intro: "Sit tall. Breathe through the nose. Let awareness rise through the seven chakras on the inhale and descend on the exhale. Visualize light moving up and down the spine.",
            steps: steps,
            loop: true
        )
    }()

    // Anxiety reduction: Belly, Ribs, Chest; then exhale reverse. Add 2-count pauses.
    static let anxietyReduction: BreathPracticeModel = {
        let steps: [BreathStep] = [
            BreathStep(title: "Inhale – Belly", subtitle: "Let the belly rise.", duration: 4),
            BreathStep(title: "Inhale – Ribs", subtitle: "Let the ribs expand sideways.", duration: 4),
            BreathStep(title: "Inhale – Chest", subtitle: "Let breath rise to chest and collarbones.", duration: 4),
            BreathStep(title: "Pause", subtitle: "Hold gently for 2 counts.", duration: 2),
            BreathStep(title: "Exhale – Chest", subtitle: "Soften the chest.", duration: 4),
            BreathStep(title: "Exhale – Ribs", subtitle: "Soften the ribs.", duration: 4),
            BreathStep(title: "Exhale – Belly", subtitle: "Soften the belly.", duration: 4),
            BreathStep(title: "Pause", subtitle: "Rest for 2 counts.", duration: 2),
            BreathStep(title: "Mantra – Inhale", subtitle: "I am calm and centered.", duration: 4),
            BreathStep(title: "Mantra – Exhale", subtitle: "I release tension and fear.", duration: 4)
        ]
        return BreathPracticeModel(
            title: "Anxiety Reduction",
            intro: "Sit or lie comfortably. One hand on belly, one on chest. Inhale through the nose, exhale through the nose. Move the breath in three parts with gentle pauses.",
            steps: steps,
            loop: true
        )
    }()
}

#Preview {
    NavigationStack { BreathPracticeView(model: .anxietyReduction) }
}
