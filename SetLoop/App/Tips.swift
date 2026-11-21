import Foundation
import SwiftUI
import TipKit

// First-run hints (SPEC D23, DESIGN V11): each shows once, none on the workout screen.

/// Top of the timer list on first launch: what the example cards do.
struct ListIntroTip: Tip {
    var id: String { TipsSetup.id("listIntro") }
    var title: Text { Text("Start with an example") }
    var message: Text? {
        Text("▶ starts right away. Tap a card to see its steps. Build your own with +.")
    }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// Swipe and long press on a card are invisible otherwise; shown after the user has opened a timer.
struct CardActionsTip: Tip {
    @Parameter static var introDone: Bool = false
    @Parameter static var openedTimer: Bool = false

    var id: String { TipsSetup.id("cardActions") }
    var title: Text { Text("More actions") }
    var message: Text? {
        Text("Swipe a card left to edit, duplicate or delete it. Or touch and hold it.")
    }
    var image: Image? { Image(systemName: "hand.draw") }
    var rules: [Rule] {
        #Rule(Self.$introDone) { $0 }
        #Rule(Self.$openedTimer) { $0 }
    }
}

/// On the preview's Start button.
struct StartTip: Tip {
    var id: String { TipsSetup.id("start") }
    var title: Text { Text("Start the workout") }
    var message: Text? {
        Text("Sounds and voice mark every step. The timer keeps running on the Lock Screen.")
    }
}

/// Top of the editor: blocks and cycles.
struct BlockTip: Tip {
    var id: String { TipsSetup.id("block") }
    var title: Text { Text("Blocks repeat") }
    var message: Text? {
        Text("A block is a group of steps. Cycles set how many times it runs. Sets repeat the whole workout.")
    }
    var image: Image? { Image(systemName: "repeat") }
}

/// On "Select Steps", after the block tip is closed.
struct MergeTip: Tip {
    @Parameter static var blockTipDone: Bool = false

    var id: String { TipsSetup.id("merge") }
    var title: Text { Text("Make a block from steps") }
    var message: Text? {
        Text("Select neighboring steps and merge them into a block with its own cycles.")
    }
    var rules: [Rule] {
        #Rule(Self.$blockTipDone) { $0 }
    }
}

/// On the summary after the first workout.
struct HistoryTip: Tip {
    var id: String { TipsSetup.id("history") }
    var title: Text { Text("Keep it in History") }
    var message: Text? {
        Text("Save, and the workout appears in the History tab with its time, steps and note.")
    }
    var image: Image? { Image(systemName: "clock.arrow.circlepath") }
}

@MainActor
enum TipsSetup {
    nonisolated private static let generationKey = "tipsGeneration"
    private static let checkedUpgradeKey = "tipsCheckedUpgrade"
    private static let upgradePendingKey = "tipsUpgradePending"

    /// Bumped by "Show Tips Again": tips with a new ID start unseen. TipKit's own reset works
    /// only before `Tips.configure`, which would mean restarting the app.
    static var generation: Int { UserDefaults.standard.integer(forKey: generationKey) }

    nonisolated static func id(_ name: String) -> String {
        "\(name).\(UserDefaults.standard.integer(forKey: generationKey))"
    }

    /// Once per install, before the example timers are seeded: their flag is already set only
    /// for someone updating from 1.0, who knows the basics. Called from the store setup too,
    /// since an App Intent may open the store before the app's UI exists.
    static func classifyInstall() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: checkedUpgradeKey) else { return }
        defaults.set(true, forKey: checkedUpgradeKey)
        defaults.set(defaults.bool(forKey: PresetSeeder.key), forKey: upgradePendingKey)
    }

    static func configure() {
        let arguments = ProcessInfo.processInfo.arguments
        // App Store screenshots and UI checks: -hideTips / -showAllTips.
        if arguments.contains("-hideTips") { Tips.hideAllTipsForTesting() }
        if arguments.contains("-showAllTips") { Tips.showAllTipsForTesting() }
        try? Tips.configure([.displayFrequency(.immediate)])

        classifyInstall()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: upgradePendingKey) else { return }
        defaults.set(false, forKey: upgradePendingKey)
        // Keep only the hidden gestures for them.
        ListIntroTip().invalidate(reason: .actionPerformed)
        StartTip().invalidate(reason: .actionPerformed)
        BlockTip().invalidate(reason: .actionPerformed)
        HistoryTip().invalidate(reason: .actionPerformed)
        CardActionsTip.introDone = true
        MergeTip.blockTipDone = true
    }

    /// Settings → Show Tips Again.
    static func showAgain() {
        UserDefaults.standard.set(generation + 1, forKey: generationKey)
        CardActionsTip.introDone = false
        CardActionsTip.openedTimer = false
        MergeTip.blockTipDone = false
    }
}

extension View {
    /// Runs `action` once `tip` is closed or its action is done, to show the next tip in a chain.
    func onTipInvalidated(_ tip: some Tip, perform action: @escaping @MainActor () -> Void) -> some View {
        task(id: tip.id) {
            for await status in tip.statusUpdates {
                if case .invalidated = status {
                    action()
                    return
                }
            }
        }
    }
}
