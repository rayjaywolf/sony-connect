import SwiftUI

private struct CardTintKey: EnvironmentKey {
    static let defaultValue = Color.accentColor
}

extension EnvironmentValues {
    var cardTint: Color {
        get { self[CardTintKey.self] }
        set { self[CardTintKey.self] = newValue }
    }
}

struct Card<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = .accentColor, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.13), tint.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.2))
        )
        .environment(\.cardTint, tint)
        .tint(tint)
        .animation(.smooth(duration: 0.35), value: tint)
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

struct IconBadge: View {
    let symbol: String
    var active = false
    @Environment(\.cardTint) private var tint

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.15)))
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.white : tint)
        }
        .frame(width: 26, height: 26)
        .animation(.smooth(duration: 0.25), value: active)
    }
}

struct TileOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let symbol: String
    var tint: Color?

    var id: Value { value }
}

struct TilePicker<Value: Hashable>: View {
    let options: [TileOption<Value>]
    let selection: Value
    var compact = false
    let select: (Value) -> Void
    @Environment(\.cardTint) private var cardTint

    private var selectedTint: Color {
        options.first { $0.value == selection }?.tint ?? cardTint
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width / CGFloat(max(options.count, 1))
            let index = CGFloat(options.firstIndex { $0.value == selection } ?? 0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous)
                    .fill(selectedTint.gradient.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18))
                    )
                    .frame(width: width)
                    .offset(x: index * width)

                HStack(spacing: 0) {
                    ForEach(options) { option in
                        tile(option, selected: option.value == selection)
                            .frame(width: width, height: geometry.size.height)
                    }
                }
            }
        }
        .frame(height: compact ? 28 : 56)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selection)
    }

    @ViewBuilder
    private func tile(_ option: TileOption<Value>, selected: Bool) -> some View {
        Button {
            select(option.value)
        } label: {
            Group {
                if compact {
                    HStack(spacing: 5) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 11, weight: .medium))
                        Text(option.title)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                    }
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .frame(height: 18)
                            .symbolEffect(.bounce, value: selected)
                        Text(option.title)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToggleRow: View {
    let title: String
    var detail: String?
    let symbol: String
    var artwork: NSImage?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let artwork {
                Image(nsImage: artwork)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 46, height: 26)
                    .foregroundStyle(Color.white.opacity(isOn ? 1 : 0.4))
                    .animation(.smooth(duration: 0.25), value: isOn)
            } else {
                IconBadge(symbol: symbol, active: isOn)
            }
            VStack(alignment: .leading, spacing: 1) {
                if artwork == nil {
                    Text(title)
                        .font(.system(size: 13))
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let low: String
    let high: String
    let commit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: value))
                    .animation(.snappy(duration: 0.2), value: value)
            }
            HStack(spacing: 8) {
                Image(systemName: low)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Slider(value: Binding(get: { value }, set: { value = $0.rounded() }), in: range) { editing in
                    if !editing { commit() }
                }
                .controlSize(.small)
                Image(systemName: high)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
        }
    }
}

struct ExpandableCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let summary: String?
    var summarySymbol: String?
    @Binding var isOpen: Bool
    let content: Content

    init(
        title: String,
        symbol: String,
        tint: Color = .accentColor,
        summary: String?,
        summarySymbol: String? = nil,
        isOpen: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.summary = summary
        self.summarySymbol = summarySymbol
        self._isOpen = isOpen
        self.content = content()
    }

    var body: some View {
        Card(tint: tint) {
            Button {
                withAnimation(.smooth(duration: 0.3)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    IconBadge(symbol: symbol, active: isOpen)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 8)
                    if let summary, !isOpen {
                        HStack(spacing: 4) {
                            if let summarySymbol {
                                Image(systemName: summarySymbol)
                                    .font(.system(size: 9))
                            }
                            Text(summary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }
}

struct FooterButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BatteryBadge: View {
    let level: Int
    let charging: Bool

    private var fill: Color {
        if charging { return .green }
        if level <= 15 { return .red }
        if level <= 30 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(level)%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(level)))
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(fill)
                        .frame(width: max(2, 19 * CGFloat(min(level, 100)) / 100))
                        .padding(2)
                    if charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 25, height: 12)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1.5, height: 4)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .animation(.smooth(duration: 0.4), value: level)
    }
}

struct SoundMeter: View {
    let level: Int?
    let note: String?

    private let floor = 40.0
    private let ceiling = 100.0
    private let limit = 85
    private let segments = 30

    private var isLoud: Bool { (level ?? 0) >= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconBadge(symbol: "ear.badge.waveform", active: level != nil)
                Text("Sound level")
                    .font(.system(size: 13))
                Spacer()
                if let level {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(level)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(level)))
                        Text("dB")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(segmentColor(Double(level)))
                    .transition(.opacity)
                } else {
                    Text(note ?? "Measuring…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }

            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { index in
                    Capsule()
                        .fill(color(for: index))
                        .frame(height: 6)
                }
            }

            if isLoud {
                Label("Long listening at this level can damage hearing", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.35), value: level)
        .help("Measured by the headphones. The marked segments start at \(limit) dB.")
    }

    private func decibels(at index: Int) -> Double {
        floor + (ceiling - floor) * Double(index) / Double(segments)
    }

    private func segmentColor(_ db: Double) -> Color {
        let fraction = min(max((db - 55) / (Double(limit) - 55), 0), 1)
        return Color(hue: 0.36 * (1 - fraction), saturation: 0.8, brightness: 0.92)
    }

    private func color(for index: Int) -> Color {
        let db = decibels(at: index)
        guard let level, db < Double(level) else {
            return segmentColor(db).opacity(0.16)
        }
        return segmentColor(db)
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var color: Color = .accentColor
    let onCommit: () -> Void

    private let knob: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let travel = geometry.size.height - knob
            let zeroY = position(for: 0, travel: travel)
            let valueY = position(for: value, travel: travel)
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 10, height: 1)
                    .offset(y: zeroY + knob / 2)
                Capsule()
                    .fill(color.gradient)
                    .frame(width: 4, height: abs(zeroY - valueY))
                    .offset(y: min(zeroY, valueY) + knob / 2)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .frame(width: knob, height: knob)
                    .offset(y: valueY)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.snappy(duration: 0.18), value: value)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = 1 - min(max((drag.location.y - knob / 2) / travel, 0), 1)
                        let stepped = (range.lowerBound + fraction * (range.upperBound - range.lowerBound)).rounded()
                        if stepped != value { value = stepped }
                    }
                    .onEnded { _ in onCommit() }
            )
        }
    }

    private func position(for v: Double, travel: CGFloat) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        let fraction = span == 0 ? 0.5 : (v - range.lowerBound) / span
        return travel * (1 - CGFloat(fraction))
    }
}
