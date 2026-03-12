# Inner Wave — Features & Bug Log

## Version history

---

### Session 2 — New features & improvements (2026-03-12)

#### New features

- **Session history & streak tracking** — Every completed practice round is saved to `SessionStore` (persisted with `UserDefaults`). A new History tab on the home screen shows a scrollable log of past sessions (practice name, date, rounds completed) and displays the current daily streak.
- **4-7-8 Breathing practice** — A classic relaxation technique: inhale for 4 s, hold for 7 s, exhale slowly for 8 s. Listed in the practice picker.
- **Box Breathing practice** — Inhale 4 s → hold 4 s → exhale 4 s → hold 4 s. Used widely for stress regulation. Listed in the practice picker.
- **Practice picker cards** — The flat list is replaced with visually rich cards showing a SF Symbol icon, a one-line description, and a difficulty/duration tag.
- **Screen keep-awake** — `UIApplication.shared.isIdleTimerDisabled` is set to `true` while a practice is running and restored on pause/stop/disappear, preventing the screen from dimming mid-session.

#### Improvements

- `BreathPracticeModel` gains an `icon` (SF Symbol name), `description`, and `difficulty` field used by the new picker cards.

---

### Session 1 — Bug fixes & code quality (2026-03-12)

#### Bugs fixed

- **`SettingsStore` persistence bug** — `@Observable` + `didSet` caused `save()` to fire on every property assignment inside `load()`, potentially overwriting persisted values with defaults on launch. Fixed with an `isLoading` guard flag.
- **`BreathingRhythm` dead singleton** — `static let shared` was never used; the environment always received a fresh `BreathingRhythm()`. Removed the singleton.
- **Environment objects recreated on every render** — `SettingsStore()` and `BreathingRhythm()` were instantiated inside `ContentView.body`, meaning they could be re-created on every SwiftUI render pass. Lifted to `@State` on `Inner_WaveApp` so they live for the full app lifetime.
- **Dead `started` state var** — `@State private var started` in `ContentView` was never set to `true`, making the `navigationDestination(isPresented: $started)` block unreachable. Removed both.
- **Unsafe `Timer` + `RunLoop` pattern** — `Timer.scheduledTimer` required manual RunLoop management and had no guaranteed cleanup on view disappear. Replaced with a `Task { @MainActor in … }` async loop stored in `@State private var timerTask`, cancelled cleanly in all exit paths.
- **`adjustedDuration` ignored user setting** — The function hardcoded `return 4.0` for all breath steps instead of reading `settings.stepDuration`. Now correctly uses the user-configured value.
- **Dead `colorForCurrentStep()` function** — Defined but never called; pulse circle used hardcoded `.red`/`.green`. Removed the dead function and replaced with `colorForStep(_:)` which is actually called and maps each step type to a distinct meaningful colour.

#### Improvements

- **Step progress bar** — A segmented capsule bar above the breathing circle shows position within the current practice sequence.
- **Round counter** — Displays "Round N" once looping is enabled and at least one round has completed.
- **Rest screen polish** — Added a sparkles icon and improved instructional copy.
- **`#Preview` environments** — Preview macros now inject the required environment objects so Xcode Previews render correctly.
