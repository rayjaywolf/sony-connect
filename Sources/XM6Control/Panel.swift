import AppKit
import SwiftUI

struct Panel: View {
    @ObservedObject var headphones: Headphones
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var state: PanelState

    private var isConnected: Bool { headphones.status == .connected }

    var body: some View {
        VStack(spacing: 10) {
            Header(headphones: headphones)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            if isConnected {
                connectedContent
                    .transition(.opacity)
            } else {
                DisconnectedCard(headphones: headphones)
                    .transition(.opacity)
            }
            Footer(headphones: headphones, loginItem: loginItem)
                .padding(.horizontal, 2)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 666)
        .animation(.smooth(duration: 0.3), value: isConnected)
        .onAppear { headphones.startSoundLevel() }
        .onDisappear { headphones.stopSoundLevel() }
    }

    private var connectedContent: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                noiseCard
                listeningCard
                soundCard
                featuresCard
            }
            .frame(width: 316)
            VStack(spacing: 10) {
                equalizerCard
                devicesCard
            }
            .frame(width: 316)
        }
    }

    private var noiseCard: some View {
        Card {
            SectionLabel("Noise control")
            TilePicker(
                options: [
                    TileOption(value: NoiseMode.noiseCancelling, title: "Noise cancelling", symbol: "waveform.badge.minus"),
                    TileOption(value: NoiseMode.ambient, title: "Ambient", symbol: "ear"),
                    TileOption(value: NoiseMode.off, title: "Off", symbol: "circle.slash"),
                ],
                selection: headphones.mode,
                select: headphones.setMode
            )
            if headphones.mode == .ambient {
                VStack(spacing: 10) {
                    ValueSlider(
                        title: "Ambient level",
                        value: $headphones.ambientLevel,
                        range: 1...20,
                        low: "speaker.wave.1",
                        high: "speaker.wave.3",
                        commit: headphones.commitAmbientLevel
                    )
                    ToggleRow(
                        title: "Focus on voice",
                        symbol: "person.wave.2",
                        isOn: Binding(get: { headphones.focusOnVoice }, set: headphones.setFocusOnVoice)
                    )
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.28), value: headphones.mode)
    }

    private var listeningCard: some View {
        Card {
            SectionLabel("Listening mode")
            TilePicker(
                options: [
                    TileOption(value: ListeningMode.standard, title: "Standard", symbol: "music.note"),
                    TileOption(value: ListeningMode.backgroundMusic, title: "Background", symbol: "music.note.house"),
                    TileOption(value: ListeningMode.cinema, title: "Cinema", symbol: "film"),
                ],
                selection: headphones.listeningMode,
                select: headphones.setListeningMode
            )
            if headphones.listeningMode == .backgroundMusic {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Room size")
                    TilePicker(
                        options: [
                            TileOption(value: RoomSize.myRoom, title: "My room", symbol: "bed.double"),
                            TileOption(value: RoomSize.livingRoom, title: "Living room", symbol: "sofa"),
                            TileOption(value: RoomSize.cafe, title: "Café", symbol: "cup.and.saucer"),
                        ],
                        selection: headphones.roomSize,
                        compact: true,
                        select: headphones.setRoomSize
                    )
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.28), value: headphones.listeningMode)
    }

    private var soundCard: some View {
        Card {
            ValueSlider(
                title: "Volume",
                value: $headphones.volume,
                range: 0...30,
                low: "speaker.fill",
                high: "speaker.wave.3.fill",
                commit: headphones.commitVolume
            )
            Divider().opacity(0.6)
            SoundMeter(level: headphones.soundLevel, note: headphones.soundLevelNote)
        }
    }

    private var featuresCard: some View {
        Card {
            ToggleRow(
                title: "DSEE Extreme",
                detail: "Restores detail in compressed music",
                symbol: "sparkles",
                isOn: Binding(get: { headphones.dsee }, set: headphones.setDSEE)
            )
        }
    }

    private var equalizerCard: some View {
        ExpandableCard(
            title: "Equalizer",
            symbol: "slider.vertical.3",
            summary: headphones.currentEqPreset?.name,
            isOpen: $state.equalizerOpen
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Preset", selection: Binding(
                    get: { headphones.currentEqPreset },
                    set: { if let preset = $0 { headphones.selectEqPreset(preset) } }
                )) {
                    ForEach(headphones.eqPresets) { preset in
                        Text(preset.name).tag(Optional(preset))
                    }
                }
                .labelsHidden()

                if headphones.eqPresetID != 0x00, !headphones.eqBands.isEmpty {
                    EqualizerBands(headphones: headphones)
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.25), value: headphones.eqPresetID)
        }
    }

    private var devicesCard: some View {
        ExpandableCard(
            title: "Devices",
            symbol: "laptopcomputer.and.iphone",
            summary: headphones.devices.first(where: \.playing)?.name,
            summarySymbol: headphones.playbackFixed ? "lock.fill" : nil,
            isOpen: $state.devicesOpen
        ) {
            VStack(alignment: .leading, spacing: 8) {
                let connected = headphones.devices.filter(\.connected).sorted { $0.playing && !$1.playing }
                if connected.isEmpty {
                    Text("Reading connected devices…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                ForEach(connected) { device in
                    DeviceRow(device: device, playbackFixed: headphones.playbackFixed) {
                        headphones.playOn(device)
                    } disconnect: {
                        headphones.setConnected(device, false)
                    }
                }
                if let failure = headphones.switchFailure {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                if let playing = headphones.devices.first(where: \.playing) {
                    Divider().opacity(0.6)
                    ToggleRow(
                        title: "Keep playback here",
                        detail: "Stays on \(playing.name)",
                        symbol: "lock",
                        isOn: Binding(get: { headphones.playbackFixed }, set: headphones.setPlaybackFixed)
                    )
                }
            }
            .animation(.smooth(duration: 0.25), value: headphones.devices)
        }
    }
}

struct Header: View {
    @ObservedObject var headphones: Headphones

    private var isConnected: Bool { headphones.status == .connected }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isConnected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07))
                Image(systemName: "headphones")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isConnected ? Color.accentColor : Color.secondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(headphones.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            Spacer()

            if isConnected, let battery = headphones.battery {
                BatteryBadge(level: battery, charging: headphones.charging)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: subtitle)
    }

    private var subtitle: String {
        switch headphones.status {
        case .connected:
            switch headphones.mode {
            case .noiseCancelling: "Noise cancelling on"
            case .ambient: "Ambient sound on"
            case .off: "Noise control off"
            }
        case .connecting: "Connecting…"
        case .notPaired: "Not paired"
        case .disconnected, .failed: "Not connected"
        }
    }
}

struct DisconnectedCard: View {
    @ObservedObject var headphones: Headphones

    var body: some View {
        Card {
            VStack(spacing: 12) {
                Image(systemName: headphones.status == .connecting ? "headphones" : "headphones.circle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, isActive: headphones.status == .connecting)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if headphones.status != .connecting, headphones.status != .notPaired {
                    Button {
                        Task { await headphones.connect(userInitiated: true) }
                    } label: {
                        Label("Connect to headphones", systemImage: "link")
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private var message: String {
        switch headphones.status {
        case .notPaired: "Pair your WH-1000XM6 in System Settings > Bluetooth, then reopen this menu."
        case .connecting: "Connecting to your headphones…"
        case .failed(let text): text
        case .disconnected, .connected: "Your headphones aren't connected to this Mac."
        }
    }
}

struct Footer: View {
    @ObservedObject var headphones: Headphones
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        HStack(spacing: 14) {
            Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.set)) {
                Text("Open at login")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Spacer()

            if headphones.status == .connected {
                FooterButton(title: "Disconnect", symbol: "bolt.horizontal.circle") {
                    headphones.disconnect()
                }
            }
            FooterButton(title: "Quit", symbol: "power") {
                NSApp.terminate(nil)
            }
        }
    }
}

struct DeviceRow: View {
    let device: PairedDevice
    let playbackFixed: Bool
    let play: () -> Void
    let disconnect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, active: device.playing)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if device.playing {
                Image(systemName: playbackFixed ? "lock.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !playbackFixed)
                    .help(playbackFixed ? "Playback is kept on this device" : "Playing on this device")
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: play) {
                    Label("Play here", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .transition(.opacity)
            }
        }
        .contextMenu {
            if !device.playing {
                Button("Play on \(device.name)", action: play)
            }
            Button("Disconnect \(device.name)", action: disconnect)
        }
    }

    private var statusText: String {
        if device.playing { return playbackFixed ? "Playing, kept here" : "Playing" }
        return "Connected"
    }

    private var symbol: String {
        let name = device.name.lowercased()
        if name.contains("macbook") { return "laptopcomputer" }
        if name.contains("imac") || name.contains("mac mini") || name.contains("mac studio") { return "desktopcomputer" }
        if name.contains("ipad") || name.contains("tab") { return "ipad" }
        if name.contains("iphone") || name.contains("galaxy") || name.contains("pixel") || name.contains("phone")
            || name.range(of: #"\bs\d{2}\b"#, options: .regularExpression) != nil {
            return "iphone"
        }
        if name.contains("tv") { return "tv" }
        return "dot.radiowaves.left.and.right"
    }
}

struct EqualizerBands: View {
    @ObservedObject var headphones: Headphones

    private static let tenBandLabels = ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    private static let fiveBandLabels = ["400", "1k", "2.5k", "6.3k", "16k"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 0) {
                if headphones.hasClearBass {
                    band(label: "Bass", value: $headphones.clearBass)
                }
                ForEach(headphones.eqBands.indices, id: \.self) { index in
                    band(label: label(for: index), value: Binding(
                        get: { headphones.eqBands.indices.contains(index) ? headphones.eqBands[index] : 0 },
                        set: { if headphones.eqBands.indices.contains(index) { headphones.eqBands[index] = $0 } }
                    ))
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            if headphones.currentEqPreset?.isCustomizable != true {
                Label("Moving a slider switches to Custom", systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(for index: Int) -> String {
        let labels = headphones.eqBands.count == 10 ? Self.tenBandLabels : Self.fiveBandLabels
        return labels.indices.contains(index) ? labels[index] : "\(index + 1)"
    }

    private func band(label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 5) {
            Text(value.wrappedValue > 0 ? "+\(Int(value.wrappedValue))" : "\(Int(value.wrappedValue))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value.wrappedValue == 0 ? .secondary : .primary)
                .contentTransition(.numericText(value: value.wrappedValue))
            VerticalSlider(value: value, range: headphones.eqBandRange) {
                headphones.commitEqBands()
            }
            .frame(width: 22, height: 104)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
