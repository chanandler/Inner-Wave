import SwiftUI

@Observable
final class BreathingRhythm {
    static let shared = BreathingRhythm()
    
    var isRunning: Bool = false
    var currentDuration: TimeInterval = 4.0

    init() {}
}
