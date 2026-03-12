import SwiftUI

// MARK: - Model

struct PracticeSession: Codable, Identifiable {
    let id: UUID
    let practiceName: String
    let date: Date
    let roundsCompleted: Int

    init(practiceName: String, date: Date = .now, roundsCompleted: Int) {
        self.id = UUID()
        self.practiceName = practiceName
        self.date = date
        self.roundsCompleted = roundsCompleted
    }
}

// MARK: - Store

@Observable
final class SessionStore {
    private(set) var sessions: [PracticeSession] = []

    /// Number of consecutive calendar days that include at least one session,
    /// counting backwards from today.
    var streak: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        // Streak only counts if there's a session today or yesterday
        guard days.contains(today) || days.contains(calendar.date(byAdding: .day, value: -1, to: today)!) else {
            return 0
        }
        var count = 0
        var cursor = today
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    init() { load() }

    func record(practiceName: String, roundsCompleted: Int) {
        guard roundsCompleted > 0 else { return }
        let session = PracticeSession(practiceName: practiceName, roundsCompleted: roundsCompleted)
        sessions.insert(session, at: 0)
        save()
    }

    // MARK: - Persistence

    private static let storageKey = "practiceSessionsV1"

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([PracticeSession].self, from: data) else { return }
        sessions = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}

// MARK: - History View

struct HistoryView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "wind",
                        description: Text("Complete a practice to see your history here.")
                    )
                } else {
                    List {
                        // Streak banner
                        if store.streak > 0 {
                            Section {
                                HStack(spacing: 12) {
                                    Image(systemName: "flame.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(store.streak) day streak")
                                            .font(.headline)
                                        Text("Keep it going!")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Session log
                        Section("Past Sessions") {
                            ForEach(store.sessions) { session in
                                SessionRow(session: session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct SessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lungs.fill")
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.practiceName)
                    .font(.subheadline).bold()
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(session.roundsCompleted) \(session.roundsCompleted == 1 ? "round" : "rounds")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .environment({
            let s = SessionStore()
            s.record(practiceName: "Anxiety Reduction", roundsCompleted: 3)
            s.record(practiceName: "Box Breathing", roundsCompleted: 1)
            return s
        }())
}
