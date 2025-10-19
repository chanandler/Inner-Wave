import SwiftUI

struct ContentView: View {
    @State private var started = false
    @State private var showPracticePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background gradient
                LinearGradient(colors: [.indigo.opacity(0.2), .mint.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    MandalaView()
                        .frame(width: 180, height: 180)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                showPracticePicker = true
                            }
                        }
                        .accessibilityLabel("Begin Three-Part Breath")
                        .accessibilityAddTraits(.isButton)

                    Text("Tap the mandala to begin")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $started) {
                PracticePickerView()
            }
            .sheet(isPresented: $showPracticePicker) {
                PracticePickerView()
                    .presentationDetents([.medium, .large])
            }
        }
        .environment(SettingsStore())
    }
}

private struct PracticePickerView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Three-Part Breath Practices") {
                    NavigationLink("Chakra Activation") {
                        BreathPracticeView(model: .chakraActivation)
                    }
                    NavigationLink("Anxiety Reduction") {
                        BreathPracticeView(model: .anxietyReduction)
                    }
                }
            }
            .navigationTitle("Choose Practice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }
}

private struct MandalaView: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay(
                    Circle().stroke(AngularGradient(gradient: Gradient(colors: [.purple, .blue, .mint, .purple]), center: .center), lineWidth: 3)
                )
                .shadow(radius: 8)

            Image(systemName: "circle.hexagongrid")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.purple, .blue)
                .padding(28)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: rotate)
                .onAppear { rotate = true }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
