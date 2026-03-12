import SwiftUI

@Observable
final class BreathingRhythm {
    var isRunning: Bool = false
    var currentDuration: TimeInterval = 4.0

    init() {}
}
