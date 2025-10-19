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
                        .frame(width: 280, height: 280)
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
                    .presentationDetents([.large, .fraction(0.9), .medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .environment(SettingsStore())
        .environment(BreathingRhythm())
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
    @Environment(SettingsStore.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(BreathingRhythm.self) private var rhythm
    
    @State private var rotate = false
    @State private var breathe = false

    var body: some View {
        let themeColors: [Color] = {
            switch settings.mandalaTheme {
            case .chakra:
                // Root to Crown continuous gradient
                return [.red, .orange, .yellow, .green, .blue, .indigo, .purple]
            case .coolGlow:
                return [.purple, .indigo, .blue, .mint, .teal]
            case .warmSunset:
                return [.pink, .orange, .yellow, .red]
            case .monochrome:
                return [colorScheme == .dark ? .white : .black, .gray]
            }
        }()

        ZStack {
            // Glow backdrop
            Circle()
                .fill(AngularGradient(colors: themeColors.map { $0.opacity(0.2) }, center: .center))
                .blur(radius: 20)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let minSide = min(size.width, size.height)
                let baseRadius = minSide * 0.42

                func rotate(_ p: CGPoint, by angle: CGFloat, around c: CGPoint) -> CGPoint {
                    let dx = p.x - c.x, dy = p.y - c.y
                    let r = hypot(dx, dy)
                    let theta = atan2(dy, dx) + angle
                    return CGPoint(x: c.x + r * cos(theta), y: c.y + r * sin(theta))
                }

                // Colors & styles
                let stroke1 = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                let stroke2 = StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round, dash: [2, 4])
                let grad = Gradient(colors: themeColors)
                let linear = GraphicsContext.Shading.linearGradient(grad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height))
                // Removed angular gradient shading as not available
                // let angular = GraphicsContext.Shading.angularGradient(grad, center: center)

                // Helper to draw a ring
                func ring(radius: CGFloat, lineWidth: CGFloat) {
                    var path = Path()
                    path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(path, with: linear, style: StrokeStyle(lineWidth: lineWidth))
                }

                // Concentric rings
                ring(radius: baseRadius * 0.35, lineWidth: 1)
                ring(radius: baseRadius * 0.55, lineWidth: 1)
                ring(radius: baseRadius * 0.75, lineWidth: 1)

                // Lotus petals layer
                let petals = 12
                for i in 0..<petals {
                    let angle = (CGFloat(i) / CGFloat(petals)) * 2 * .pi
                    var petal = Path()
                    let r1 = baseRadius * 0.25
                    let r2 = baseRadius * 0.60
                    let r3 = baseRadius * 0.75
                    let p1 = CGPoint(x: center.x + r1 * cos(angle), y: center.y + r1 * sin(angle))
                    let p2 = CGPoint(x: center.x + r2 * cos(angle), y: center.y + r2 * sin(angle))
                    let p3a = rotate(CGPoint(x: center.x + r3 * cos(angle), y: center.y + r3 * sin(angle)), by: .pi/24, around: center)
                    let p3b = rotate(CGPoint(x: center.x + r3 * cos(angle), y: center.y + r3 * sin(angle)), by: -.pi/24, around: center)
                    petal.move(to: p1)
                    petal.addQuadCurve(to: p3a, control: p2)
                    petal.move(to: p1)
                    petal.addQuadCurve(to: p3b, control: p2)
                    context.stroke(petal, with: linear, style: stroke1)
                }

                // Inner star polygon
                var star = Path()
                let points = 8
                for i in 0..<(points * 2) {
                    let a = (CGFloat(i) / CGFloat(points * 2)) * 2 * .pi
                    let r = i % 2 == 0 ? baseRadius * 0.28 : baseRadius * 0.12
                    let pt = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
                    if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                context.stroke(star, with: linear, style: stroke1)

                // Dotted orbit
                let dots = 36
                let dotRadius = baseRadius * 0.80
                for i in 0..<dots {
                    let a = (CGFloat(i) / CGFloat(dots)) * 2 * .pi
                    let pt = CGPoint(x: center.x + dotRadius * cos(a), y: center.y + dotRadius * sin(a))
                    let dot = Path(ellipseIn: CGRect(x: pt.x - 1, y: pt.y - 1, width: 2, height: 2))
                    context.fill(dot, with: .color(.white.opacity(0.7)))
                }

                // Radial filigree
                let rays = 24
                for i in 0..<rays {
                    let a = (CGFloat(i) / CGFloat(rays)) * 2 * .pi
                    var ray = Path()
                    let rIn = baseRadius * 0.15
                    let rOut = baseRadius * 0.85
                    let mid = baseRadius * 0.55
                    let pIn = CGPoint(x: center.x + rIn * cos(a), y: center.y + rIn * sin(a))
                    let pMid = CGPoint(x: center.x + mid * cos(a), y: center.y + mid * sin(a))
                    let pOut = CGPoint(x: center.x + rOut * cos(a), y: center.y + rOut * sin(a))
                    ray.move(to: pIn)
                    ray.addQuadCurve(to: pOut, control: pMid)
                    context.stroke(ray, with: linear, style: stroke2)
                }
            }
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: rotate)
            .scaleEffect(breathe ? 1.03 : 0.97)
            .animation(.easeInOut(duration: rhythm.isRunning ? max(0.5, rhythm.currentDuration) : 4).repeatForever(autoreverses: true), value: breathe)
            .onAppear { rotate = true; breathe = true }

            // Foreground glass ring
            Circle()
                .strokeBorder(.thinMaterial, lineWidth: 2)
        }
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
    }
}

#Preview {
    ContentView()
}
