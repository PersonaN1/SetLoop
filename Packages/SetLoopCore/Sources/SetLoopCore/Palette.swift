import Foundation

/// 24-bit RGB color, e.g. `RGB(0xE8452C)`.
public struct RGB: Codable, Hashable, Sendable {
    public var hex: UInt32

    public init(_ hex: UInt32) { self.hex = hex & 0xFFFFFF }

    public var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    public var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(hex & 0xFF) / 255 }

    public init(red: Double, green: Double, blue: Double) {
        func byte(_ value: Double) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        self.init(byte(red) << 16 | byte(green) << 8 | byte(blue))
    }

    /// Brighter variant for text on the always-black Dynamic Island (DESIGN V10).
    public var lightened: RGB {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        guard maxC > 0 else { return self }
        let saturation = (maxC - minC) / maxC * 0.85
        func channel(_ value: Double) -> Double {
            let relative = maxC == minC ? 1 : (value - minC) / (maxC - minC)
            return 1 - saturation * (1 - relative)
        }
        return RGB(red: channel(red), green: channel(green), blue: channel(blue))
    }
}

/// The 12 colors available for step types (DESIGN V2).
public enum Palette {
    public static let colors: [RGB] = [
        0xE8452C, 0xD63C7E, 0x9C2BB0, 0x7B4FD6, 0x4B55C9, 0x2F6BDB,
        0x0E7C9E, 0x0F8A8A, 0x1E8E52, 0x5F8F1A, 0xB86200, 0x5B6470,
    ].map(RGB.init)
}

/// Global type → color mapping, set in Settings → Step colors (SPEC D17).
public struct StepColors: Codable, Hashable, Sendable {
    public var colors: [StepType: RGB]

    public init(colors: [StepType: RGB]) {
        self.colors = colors
    }

    public static let `default` = StepColors(colors: [
        .prepare: RGB(0x5B6470),
        .workA: RGB(0xE8452C),
        .workB: RGB(0x9C2BB0),
        .workC: RGB(0xB86200),
        .rest: RGB(0x1E8E52),
        .cooldown: RGB(0x5B6470),
    ])

    public subscript(type: StepType) -> RGB {
        colors[type] ?? Self.default.colors[type]!
    }

    /// Rest and work must stay distinguishable: the rest color can't be picked for work and vice versa (DESIGN V8).
    public func isAllowed(_ color: RGB, for type: StepType) -> Bool {
        switch type.category {
        case .work: color != self[.rest]
        case .rest: ![StepType.workA, .workB, .workC].contains { self[$0] == color }
        case .other: true
        }
    }
}

/// Stored as `{"colors": {"workA": {"hex": …}}}`. Older builds wrote the enum-keyed dictionary
/// as a flat `[key, value, key, value…]` array; both are read, and unknown types are skipped.
extension StepColors {
    private enum CodingKeys: String, CodingKey {
        case colors
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var colors: [StepType: RGB] = [:]
        if let keyed = try? container.decode([String: RGB].self, forKey: .colors) {
            for (key, color) in keyed {
                if let type = StepType(rawValue: key) { colors[type] = color }
            }
        } else {
            var legacy = try container.nestedUnkeyedContainer(forKey: .colors)
            while !legacy.isAtEnd {
                let key = try legacy.decode(String.self)
                let color = try legacy.decode(RGB.self)
                if let type = StepType(rawValue: key) { colors[type] = color }
            }
        }
        self.colors = colors
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let keyed = Dictionary(uniqueKeysWithValues: colors.map { ($0.key.rawValue, $0.value) })
        try container.encode(keyed, forKey: .colors)
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension RGB {
    public var color: Color { Color(red: red, green: green, blue: blue) }
}
#endif
