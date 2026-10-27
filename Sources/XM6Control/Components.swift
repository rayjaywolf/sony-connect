import SwiftUI

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.border)
        )
        .tint(Theme.accent)
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.font(11, .medium))
            .foregroundStyle(Theme.muted)
    }
}

struct IconBadge: View {
    let symbol: String
    var active = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .fill(active ? Theme.accent : Theme.default)
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Theme.accentForeground : Theme.muted)
        }
        .frame(width: 26, height: 26)
        .animation(.smooth(duration: 0.2), value: active)
    }
}

struct TileOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let symbol: String

    var id: Value { value }
}

struct TilePicker<Value: Hashable>: View {
    let options: [TileOption<Value>]
    let selection: Value
    var compact = false
    let select: (Value) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width / CGFloat(max(options.count, 1))
            let index = CGFloat(options.firstIndex { $0.value == selection } ?? 0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.fieldRadius - 3, style: .continuous)
                    .fill(Theme.segment)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
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
        .frame(height: compact ? 26 : 52)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
                .fill(Theme.default)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selection)
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
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selected ? Theme.accent : Theme.muted)
                        Text(option.title)
                            .font(Theme.font(11, selected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 15, weight: .medium))
                            .frame(height: 18)
                            .foregroundStyle(selected ? Theme.accent : Theme.muted)
                        Text(option.title)
                            .font(Theme.font(11, selected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .foregroundStyle(selected ? Theme.foreground : Theme.muted)
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
                    .foregroundStyle(isOn ? Theme.foreground : Theme.muted.opacity(0.6))
                    .animation(.smooth(duration: 0.2), value: isOn)
            } else {
                IconBadge(symbol: symbol, active: isOn)
            }
            VStack(alignment: .leading, spacing: 1) {
                if artwork == nil {
                    Text(title)
                        .font(Theme.font(13, .medium))
                        .foregroundStyle(Theme.foreground)
                }
                if let detail {
                    Text(detail)
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(Theme.accent)
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
                    .font(Theme.font(13, .medium))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Text("\(Int(value))")
                    .font(Theme.font(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText(value: value))
                    .animation(.snappy(duration: 0.2), value: value)
            }
            HStack(spacing: 8) {
                Image(systemName: low)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16)
                Slider(value: Binding(get: { value }, set: { value = $0.rounded() }), in: range) { editing in
                    if !editing { commit() }
                }
                .controlSize(.small)
                .tint(Theme.accent)
                Image(systemName: high)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16)
            }
        }
    }
}

struct ExpandableCard<Content: View>: View {
    let title: String
    let symbol: String
    let summary: String?
    var summarySymbol: String?
    @Binding var isOpen: Bool
    let content: Content

    init(
        title: String,
        symbol: String,
        summary: String?,
        summarySymbol: String? = nil,
        isOpen: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.summarySymbol = summarySymbol
        self._isOpen = isOpen
        self.content = content()
    }

    var body: some View {
        Card {
            Button {
                withAnimation(.smooth(duration: 0.3)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    IconBadge(symbol: symbol, active: isOpen)
                    Text(title)
                        .font(Theme.font(13, .semibold))
                        .foregroundStyle(Theme.foreground)
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
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.muted)
                        .transition(.opacity)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
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
                .font(Theme.font(12, .medium))
                .foregroundStyle(Theme.muted)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
    }
}

struct BatteryBadge: View {
    let level: Int
    let charging: Bool

    private var fill: Color {
        if charging { return Theme.success }
        if level <= 15 { return Theme.danger }
        if level <= 30 { return Theme.warning }
        return Theme.success
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(level)%")
                .font(Theme.font(12, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.defaultForeground)
                .contentTransition(.numericText(value: Double(level)))
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(Theme.muted.opacity(0.6), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(fill)
                        .frame(width: max(2, 19 * CGFloat(min(level, 100)) / 100))
                        .padding(2)
                    if charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.accentForeground)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 25, height: 12)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.muted.opacity(0.6))
                    .frame(width: 1.5, height: 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
                .fill(Theme.default)
        )
        .animation(.smooth(duration: 0.4), value: level)
    }
}

struct SoundMeter: View {
    let level: Int?
    let note: String?

    private let floor = 40.0
    private let ceiling = 100.0
    private let caution = 75
    private let limit = 85
    private let segments = 30

    private var isLoud: Bool { (level ?? 0) >= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconBadge(symbol: "ear.badge.waveform", active: level != nil)
                Text("Sound level")
                    .font(Theme.font(13, .medium))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                if let level {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(level)")
                            .font(Theme.font(17, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(level >= limit ? Theme.danger : Theme.foreground)
                            .contentTransition(.numericText(value: Double(level)))
                        Text("dB")
                            .font(Theme.font(11, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .transition(.opacity)
                } else {
                    Text(note ?? "Measuring…")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.muted)
                        .transition(.opacity)
                }
            }

            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(color(for: index))
                        .frame(height: 6)
                }
            }

            if isLoud {
                Label("Long listening at this level can damage hearing", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.font(11, .medium))
                    .foregroundStyle(Theme.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.35), value: level)
        .help("Measured by the headphones. Segments turn yellow from \(caution) dB and red from \(limit) dB.")
    }

    private func decibels(at index: Int) -> Double {
        floor + (ceiling - floor) * Double(index) / Double(segments)
    }

    private func color(for index: Int) -> Color {
        let db = decibels(at: index)
        guard let level, db < Double(level) else { return Theme.default }
        if db >= Double(limit) { return Theme.danger }
        if db >= Double(caution) { return Theme.warning }
        return Theme.accent
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    private let knob: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let travel = geometry.size.height - knob
            let zeroY = position(for: 0, travel: travel)
            let valueY = position(for: value, travel: travel)
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Theme.default)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 10, height: 1)
                    .offset(y: zeroY + knob / 2)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 4, height: abs(zeroY - valueY))
                    .offset(y: min(zeroY, valueY) + knob / 2)
                Circle()
                    .fill(Theme.field)
                    .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 2))
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
