#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Live Activity / Dynamic Island data (TECH T10). Updated locally on each step change and pause.
public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var stepName: String
        public var stepType: StepType
        public var color: RGB
        /// Countdown target while running; nil while paused.
        public var stepEnd: Date?
        public var stepStart: Date?
        /// Remaining seconds while paused.
        public var pausedRemaining: TimeInterval?
        /// "Cycle 2/3 · Set 1/4", already localized.
        public var positionText: String
        /// "Next: Rest 0:05", already localized; nil on the last step.
        public var nextText: String?

        public var isPaused: Bool { stepEnd == nil }

        public init(stepName: String, stepType: StepType, color: RGB, stepEnd: Date?, stepStart: Date?,
                    pausedRemaining: TimeInterval?, positionText: String, nextText: String?) {
            self.stepName = stepName
            self.stepType = stepType
            self.color = color
            self.stepEnd = stepEnd
            self.stepStart = stepStart
            self.pausedRemaining = pausedRemaining
            self.positionText = positionText
            self.nextText = nextText
        }
    }

    public var timerName: String

    public init(timerName: String) {
        self.timerName = timerName
    }
}
#endif
