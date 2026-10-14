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
        let length = { (cue: SoundCue) in Double(SoundSynth.samples(cue, in: .classic).count) / SoundSynth.sampleRate }
        #expect(length(.countdown) < 0.2)
        #expect(length(.finish) > length(.work))
    }

    @Test func stepTypesMapToCues() {
        #expect(SoundCue(.workB) == .work)
        #expect(SoundCue(.rest) == .rest)
        #expect(SoundCue(.cooldown) == .other)
    }
}
