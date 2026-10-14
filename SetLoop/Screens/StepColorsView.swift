import SetLoopCore
import SwiftUI

/// Settings → Step Colors: the palette opens inside the type's row, below are a preview strip and a reset (DESIGN V8).
struct StepColorsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var expanded: StepType?

    var body: some View {
        List {
            Section {
                ForEach(StepType.allCases, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 12) {
                        header(type)
                        if expanded == type {
                            palette(type)
                        }
                    }
                }
            } footer: {
                Text("The rest color can't be used for work, and work colors can't be used for rest.")
            }

            Section("Preview") {
                TimerStrip(definition: Self.sample, colors: settings.stepColors, height: 12)
                    .padding(.vertical, 4)
            }

            Section {
                Button("Reset to Defaults") {
                    withAnimation { settings.stepColors = .default }
                }
                .disabled(settings.stepColors == .default)
            }
        }
        .navigationTitle("Step Colors")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ type: StepType) -> some View {
        Button {
            withAnimation { expanded = expanded == type ? nil : type }
        } label: {
            HStack {
                TypeDot(color: settings.stepColors[type].color)
                Text(type.title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(Palette.name(of: settings.stepColors[type]))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded == type ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(Palette.name(of: settings.stepColors[type]))
    }

    private func palette(_ type: StepType) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Palette.colors, id: \.self) { color in
                swatch(color, for: type)
            }
        }
        .padding(.bottom, 4)
    }

    private func swatch(_ color: RGB, for type: StepType) -> some View {
        let selected = settings.stepColors[type] == color
        let allowed = settings.stepColors.isAllowed(color, for: type)
        return Button {
            settings.stepColors.colors[type] = color
        } label: {
            Circle()
                .fill(color.color.opacity(allowed || selected ? 1 : 0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                    } else if !allowed {
                        Image(systemName: "nosign")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(color.color)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
        .accessibilityLabel(Palette.name(of: color))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// One step of every type, so each color shows in the strip.
    private static let sample = TimerDefinition(
        prepare: Step(name: "", duration: 10, type: .prepare),
        blocks: [Block(steps: [
            Step(name: "", duration: 20, type: .workA),
            Step(name: "", duration: 10, type: .rest),
            Step(name: "", duration: 20, type: .workB),
            Step(name: "", duration: 10, type: .rest),
            Step(name: "", duration: 20, type: .workC),
        ])],
        cooldown: Step(name: "", duration: 10, type: .cooldown)
    )
}

extension Palette {
    /// Color names from DESIGN V2, for the row value and VoiceOver.
    static func name(of color: RGB) -> String {
        switch color.hex {
        case 0xE8452C: String(localized: "Red")
        case 0xD63C7E: String(localized: "Pink")
        case 0x9C2BB0: String(localized: "Purple")
        case 0x7B4FD6: String(localized: "Violet")
        case 0x4B55C9: String(localized: "Indigo")
        case 0x2F6BDB: String(localized: "Blue")
        case 0x0E7C9E: String(localized: "Ocean")
        case 0x0F8A8A: String(localized: "Teal")
        case 0x1E8E52: String(localized: "Green")
        case 0x5F8F1A: String(localized: "Olive")
        case 0xB86200: String(localized: "Amber")
        case 0x5B6470: String(localized: "Graphite")
        default: String(localized: "Custom")
        }
    }
}
