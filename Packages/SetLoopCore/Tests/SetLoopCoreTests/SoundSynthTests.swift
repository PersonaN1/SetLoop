import Testing
@testable import SetLoopCore

struct SoundSynthTests {
    @Test(arguments: SoundSet.allCases)
    func everyCueIsAudibleAndNormalized(set: SoundSet) {
        for cue in SoundCue.allCases {
            let samples = SoundSynth.samples(cue, in: set)
            let level = samples.map(abs).max() ?? 0
            #expect(abs(level - SoundSynth.peak) < 0.001, "\(set) \(cue)")
            // Silent edges: no clicks at start and end.
            #expect(abs(samples.first ?? 1) < 0.01)
            #expect(abs(samples.last ?? 1) < 0.01)
        }
    }

    @Test func countdownIsShortAndFinishIsLongest() {
        for set in SoundSet.allCases {
            let length = { (cue: SoundCue) in SoundSynth.samples(cue, in: set).count }
            #expect(length(.countdown) < length(.work), "\(set)")
            #expect(length(.finish) > length(.work), "\(set)")
        }
    }

    @Test func stepTypesMapToCues() {
        #expect(SoundCue(.workB) == .work)
        #expect(SoundCue(.rest) == .rest)
        #expect(SoundCue(.cooldown) == .other)
    }
}
