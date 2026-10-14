import Foundation

/// Example timers created on first launch (SPEC D9).
public enum Presets {
    public struct Preset: Sendable {
        public var name: String
        public var definition: TimerDefinition
    }

    /// Step and timer names are passed in already localized by the app.
    public struct Names: Sendable {
        public var prepare, work, rest, restBetweenSets: String
        public var tabata, simpleInterval, twoBlocks: String

        public init(prepare: String, work: String, rest: String, restBetweenSets: String,
                    tabata: String, simpleInterval: String, twoBlocks: String) {
            self.prepare = prepare
            self.work = work
            self.rest = rest
            self.restBetweenSets = restBetweenSets
            self.tabata = tabata
            self.simpleInterval = simpleInterval
            self.twoBlocks = twoBlocks
        }
    }

    public static func all(_ n: Names) -> [Preset] {
        let prepare = Step(name: n.prepare, duration: 10, type: .prepare)
        return [
            // 4:10
            Preset(name: n.tabata, definition: TimerDefinition(
                prepare: prepare,
                blocks: [Block(steps: [
                    Step(name: n.work, duration: 20, type: .workA),
                    Step(name: n.rest, duration: 10, type: .rest),
                ], repeats: 8)]
            )),
            // 10:00
            Preset(name: n.simpleInterval, definition: TimerDefinition(
                blocks: [Block(steps: [
                    Step(name: n.work, duration: 30, type: .workA),
                    Step(name: n.rest, duration: 30, type: .rest),
                ], repeats: 10)]
            )),
            // 4:52, 33 steps: 10 s/5 s ×2 + 5 s/3 s ×3, 3 sets
            Preset(name: n.twoBlocks, definition: TimerDefinition(
                prepare: prepare,
                blocks: [
                    Block(steps: [
                        Step(name: n.work, duration: 10, type: .workA),
                        Step(name: n.rest, duration: 5, type: .rest),
                    ], repeats: 2),
                    Block(steps: [
                        Step(name: n.work, duration: 5, type: .workB),
                        Step(name: n.rest, duration: 3, type: .rest),
                    ], repeats: 3),
                ],
                sets: 3,
                restBetweenSets: Step(name: n.restBetweenSets, duration: 60, type: .rest)
            )),
        ]
    }
}
