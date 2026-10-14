import Foundation

/// Names for new and duplicated timers, numbered the iOS way: "Name", "Name (2)", "Name (3)"…
public enum TimerNaming {
    /// The first free name in the "Name (N)" series. An existing "(N)" suffix is dropped first,
    /// so a copy of "Name (2)" becomes "Name (3)", not "Name (2) (2)".
    public static func unique(_ name: String, among existing: some Collection<String>) -> String {
        let taken = Set(existing)
        let base = stripNumber(name)
        if !taken.contains(base) { return base }
        var number = 2
        while taken.contains("\(base) (\(number))") { number += 1 }
        return "\(base) (\(number))"
    }

    private static func stripNumber(_ name: String) -> String {
        guard name.hasSuffix(")"), let open = name.range(of: " (", options: .backwards) else { return name }
        let digits = name[open.upperBound..<name.index(before: name.endIndex)]
        guard !digits.isEmpty, digits.allSatisfy(\.isASCII), Int(digits).map({ $0 >= 2 }) == true else { return name }
        return String(name[..<open.lowerBound])
    }
}
