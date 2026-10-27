import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let headphones = Headphones()
    let loginItem = LoginItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        headphones.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        headphones.stop()
    }
}

@main
struct XM6ControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            Panel(headphones: delegate.headphones, loginItem: delegate.loginItem)
        } label: {
            Image(systemName: "headphones")
        }
        .menuBarExtraStyle(.window)
    }
}

struct Panel: View {
    @ObservedObject var headphones: Headphones
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if headphones.status == .connected {
                controls
            } else {
                disconnected
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(headphones.name)
                .font(.headline)
            Spacer()
            if headphones.status == .connected, let battery = headphones.battery {
                Label(
                    headphones.charging ? "\(battery)% charging" : "\(battery)%",
                    systemImage: batterySymbol(battery)
                )
                .labelStyle(.titleAndIcon)
                .monospacedDigit()
                .foregroundStyle(battery <= 15 && !headphones.charging ? .red : .secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Noise control", selection: Binding(
                get: { headphones.mode },
                set: { headphones.setMode($0) }
            )) {
                Text("Noise cancelling").tag(NoiseMode.noiseCancelling)
                Text("Ambient").tag(NoiseMode.ambient)
                Text("Off").tag(NoiseMode.off)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if headphones.mode == .ambient {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledValue(title: "Ambient sound level", value: Int(headphones.ambientLevel))
                    Slider(value: $headphones.ambientLevel, in: 1...20, step: 1) { editing in
                        if !editing { headphones.commitAmbientLevel() }
                    }
                    .labelsHidden()
                    SwitchRow(title: "Focus on voice", isOn: Binding(
                        get: { headphones.focusOnVoice },
                        set: { headphones.setFocusOnVoice($0) }
                    ))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Listening mode")
                Picker("Listening mode", selection: Binding(
                    get: { headphones.listeningMode },
                    set: { headphones.setListeningMode($0) }
                )) {
                    Text("Standard").tag(ListeningMode.standard)
                    Text("Background music").tag(ListeningMode.backgroundMusic)
                    Text("Cinema").tag(ListeningMode.cinema)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if headphones.listeningMode == .backgroundMusic {
                    Picker("Room size", selection: Binding(
                        get: { headphones.roomSize },
                        set: { headphones.setRoomSize($0) }
                    )) {
                        Text("My room").tag(RoomSize.myRoom)
                        Text("Living room").tag(RoomSize.livingRoom)
                        Text("Café").tag(RoomSize.cafe)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Divider()

            equalizerSection

            Divider()

            devicesSection

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                LabeledValue(title: "Headphone volume", value: Int(headphones.volume))
                Slider(value: $headphones.volume, in: 0...30, step: 1) { editing in
                    if !editing { headphones.commitVolume() }
                }
                .labelsHidden()
            }

            Divider()

            SwitchRow(title: "DSEE Extreme", isOn: Binding(
                get: { headphones.dsee },
                set: { headphones.setDSEE($0) }
            ))
            SwitchRow(title: "Speak-to-Chat", isOn: Binding(
                get: { headphones.speakToChat },
                set: { headphones.setSpeakToChat($0) }
            ))
        }
    }

    private var equalizerSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
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
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Equalizer")
                Spacer()
                if let preset = headphones.currentEqPreset {
                    Text(preset.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var devicesSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if headphones.devices.isEmpty {
                    Text("Reading paired devices…")
                        .foregroundStyle(.secondary)
                }
                ForEach(headphones.devices.filter(\.connected)) { device in
                    DeviceRow(device: device, playbackFixed: headphones.playbackFixed) {
                        headphones.playOn(device)
                    } connect: {
                        headphones.setConnected(device, true)
                    } disconnect: {
                        headphones.setConnected(device, false)
                    }
                }
                if let failure = headphones.switchFailure {
                    Text(failure)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let playing = headphones.devices.first(where: \.playing) {
                    SwitchRow(title: "Keep playback on \(playing.name)", isOn: Binding(
                        get: { headphones.playbackFixed },
                        set: { headphones.setPlaybackFixed($0) }
                    ))
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Devices")
                Spacer()
                if let playing = headphones.devices.first(where: \.playing) {
                    if headphones.playbackFixed {
                        Image(systemName: "lock.fill")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    Text(playing.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusMessage)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if headphones.status == .connecting {
                ProgressView().controlSize(.small)
            } else if headphones.status != .notPaired {
                Button("Connect to headphones") {
                    Task { await headphones.connect(userInitiated: true) }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            SwitchRow(title: "Open at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
            HStack {
                if headphones.status == .connected {
                    Button("Disconnect controls") { headphones.disconnect() }
                }
                Spacer()
                Button("Quit XM6 Control") { NSApp.terminate(nil) }
            }
        }
    }

    private var statusMessage: String {
        switch headphones.status {
        case .notPaired: "Pair your WH-1000XM6 in System Settings > Bluetooth, then reopen this menu."
        case .disconnected: "Your headphones aren't connected to this Mac."
        case .connecting: "Connecting to your headphones…"
        case .failed(let message): message
        case .connected: ""
        }
    }

    private func batterySymbol(_ level: Int) -> String {
        if headphones.charging { return "battery.100percent.bolt" }
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Login item change failed: \(error.localizedDescription)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

struct EqualizerBands: View {
    @ObservedObject var headphones: Headphones

    private static let tenBandLabels = ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    private static let fiveBandLabels = ["400", "1k", "2.5k", "6.3k", "16k"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            if headphones.currentEqPreset?.isCustomizable != true {
                Text("Moving a slider switches to Custom.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(for index: Int) -> String {
        let labels = headphones.eqBands.count == 10 ? Self.tenBandLabels : Self.fiveBandLabels
        return labels.indices.contains(index) ? labels[index] : "\(index + 1)"
    }

    private func band(label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            Text(value.wrappedValue > 0 ? "+\(Int(value.wrappedValue))" : "\(Int(value.wrappedValue))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Slider(value: value, in: headphones.eqBandRange, step: 1) { editing in
                if !editing { headphones.commitEqBands() }
            }
            .labelsHidden()
            .controlSize(.mini)
            .frame(width: 110)
            .rotationEffect(.degrees(-90))
            .frame(width: 28, height: 110)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DeviceRow: View {
    let device: PairedDevice
    let playbackFixed: Bool
    let play: () -> Void
    let connect: () -> Void
    let disconnect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if device.playing {
                Image(systemName: playbackFixed ? "lock.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
                    .help(playbackFixed ? "Playback is kept on this device" : "Playing on this device")
            } else if device.connected {
                Button("Play here", action: play)
                    .controlSize(.small)
            } else {
                Button("Connect", action: connect)
                    .controlSize(.small)
            }
        }
        .contextMenu {
            if device.connected {
                if !device.playing {
                    Button("Play on \(device.name)", action: play)
                }
                Button("Disconnect \(device.name)", action: disconnect)
            } else {
                Button("Connect \(device.name)", action: connect)
            }
        }
    }

    private var statusText: String {
        if device.playing { return playbackFixed ? "Playing, kept on this device" : "Playing" }
        return device.connected ? "Connected" : "Not connected"
    }
}

struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

struct LabeledValue: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
