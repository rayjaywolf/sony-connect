import Foundation
import IOBluetooth
import os

enum NoiseMode: Hashable {
    case noiseCancelling, ambient, off
}

enum ListeningMode: Hashable {
    case standard, backgroundMusic, cinema
}

struct PairedDevice: Identifiable, Equatable {
    let address: String
    let name: String
    let connected: Bool
    let playing: Bool

    var id: String { address }
}

enum RoomSize: UInt8, Hashable {
    case myRoom = 0x00
    case livingRoom = 0x01
    case cafe = 0x02
}

@MainActor
final class Headphones: NSObject, ObservableObject {
    enum Status: Equatable {
        case notPaired
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var status: Status = .disconnected
    @Published private(set) var name = "WH-1000XM6"
    @Published private(set) var battery: Int?
    @Published private(set) var charging = false
    @Published private(set) var mode: NoiseMode = .noiseCancelling
    @Published private(set) var focusOnVoice = false
    @Published private(set) var dsee = false
    @Published private(set) var speakToChat = false
    @Published private(set) var listeningMode: ListeningMode = .standard
    @Published private(set) var roomSize: RoomSize = .myRoom
    @Published private(set) var devices: [PairedDevice] = []
    @Published private(set) var playbackFixed = false
    @Published private(set) var switchFailure: String?
    @Published var ambientLevel: Double = 10
    @Published var volume: Double = 15

    private static let serviceUUIDs: [[UInt8]] = [
        [0x95, 0x6C, 0x7B, 0x26, 0xD4, 0x9A, 0x4B, 0xA8, 0xB0, 0x3F, 0xB1, 0x7D, 0x39, 0x3C, 0xB6, 0xE2],
        [0x96, 0xCC, 0x20, 0x3E, 0x50, 0x68, 0x46, 0xAD, 0xB3, 0x2D, 0xE3, 0x16, 0xF5, 0xE0, 0x69, 0xBA],
    ]
    private static let fallbackChannel: BluetoothRFCOMMChannelID = 9
    private static let on: UInt8 = 0x00
    private static let off: UInt8 = 0x01

    private let log = Logger(subsystem: "com.rayjay.xm6control", category: "bluetooth")
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var reader = FrameReader()
    private var seq: UInt8 = 0
    private var pending: (id: UUID, dataType: UInt8, expects: Set<UInt8>, type: UInt8?, done: CheckedContinuation<[UInt8]?, Never>)?
    private var openWaiter: CheckedContinuation<Bool, Never>?
    private var sdpWaiter: CheckedContinuation<Void, Never>?
    private var queueTail: Task<Void, Never>?
    private var connectNotification: IOBluetoothUserNotification?
    private var batteryTimer: Timer?
    private var speakToChatSensitivity: UInt8 = 0x01
    private var speakToChatTimeout: UInt8 = 0x01
    private var recentReconnects: [Date] = []
    private var deviceListType: UInt8 = 0x02

    func start() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:fromDevice:))
        )
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.status == .connected else { return }
                await self.request([0x22, 0x00])
            }
        }
        Task { await connect(userInitiated: false) }
    }

    func stop() {
        channel?.close()
        channel = nil
    }

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        guard Self.isSonyHeadphones(device), status != .connected, status != .connecting else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await connect(userInitiated: false)
        }
    }

    func connect(userInitiated: Bool) async {
        guard status != .connecting, status != .connected else { return }
        guard let device = findDevice() else {
            status = .notPaired
            return
        }
        name = device.name ?? name
        guard userInitiated || device.isConnected() else {
            status = .disconnected
            return
        }
        status = .connecting
        self.device = device

        let channelID = await rfcommChannelID(on: device)
        log.info("Opening RFCOMM channel \(channelID, privacy: .public)")

        let opened = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            openWaiter = continuation
            var opening: IOBluetoothRFCOMMChannel?
            let result = device.openRFCOMMChannelAsync(&opening, withChannelID: channelID, delegate: self)
            if result != kIOReturnSuccess {
                log.error("openRFCOMMChannelAsync failed: \(result, privacy: .public)")
                resolveOpen(false)
                return
            }
            channel = opening
            Task {
                try? await Task.sleep(for: .seconds(10))
                self.resolveOpen(false)
            }
        }

        guard opened, channel?.isOpen() == true else {
            channel?.close()
            channel = nil
            status = .failed("Couldn't reach the headphones. Make sure they're on and connected to this Mac, then try again.")
            return
        }

        seq = 0
        reader.reset()
        await request([0x00, 0x00], timeout: 2)
        await request([0x06, 0x00], timeout: 2)
        status = .connected
        await refresh()
    }

    func disconnect() {
        status = .disconnected
        let closing = channel
        tearDown()
        closing?.close()
    }

    func refresh() async {
        await request([0x22, 0x00])
        await request([0x66, 0x19])
        await request([0xA6, 0x20])
        await request([0xE6, 0x01])
        await request([0xF6, 0x02])
        await request([0xE6, 0x09])
        await request([0xE6, 0x04])
        await refreshDevices()
        await request([0x36, 0x01], on: Frame.dataMdr2)
    }

    func refreshDevices() async {
        if await request([0x36, 0x02], on: Frame.dataMdr2) != nil {
            deviceListType = 0x02
        } else if await request([0x36, 0x00], on: Frame.dataMdr2) != nil {
            deviceListType = 0x00
        }
    }

    func playOn(_ device: PairedDevice) {
        switchFailure = nil
        devices = devices.map {
            PairedDevice(address: $0.address, name: $0.name, connected: $0.connected, playing: $0.address == device.address)
        }
        Task {
            await request([0x3C, 0x01] + Array(device.address.utf8), on: Frame.dataMdr2)
            try? await Task.sleep(for: .seconds(1))
            await refreshDevices()
        }
    }

    func setConnected(_ device: PairedDevice, _ connect: Bool) {
        Task {
            await request([0x3C, deviceListType, connect ? 0x01 : 0x00] + Array(device.address.utf8), on: Frame.dataMdr2, timeout: 1.5)
            try? await Task.sleep(for: .seconds(connect ? 4 : 2))
            await refreshDevices()
        }
    }

    func setPlaybackFixed(_ fixed: Bool) {
        playbackFixed = fixed
        Task { await request([0x38, 0x01, fixed ? 0x00 : 0x01], on: Frame.dataMdr2) }
    }

    func setListeningMode(_ newMode: ListeningMode) {
        listeningMode = newMode
        let room = roomSize.rawValue
        Task {
            switch newMode {
            case .standard:
                await request([0xE8, 0x09, Self.off, room])
                await request([0xE8, 0x04, Self.off])
            case .backgroundMusic:
                await request([0xE8, 0x04, Self.off])
                await request([0xE8, 0x09, Self.on, room])
            case .cinema:
                await request([0xE8, 0x09, Self.off, room])
                await request([0xE8, 0x04, Self.on])
            }
        }
    }

    func setRoomSize(_ size: RoomSize) {
        roomSize = size
        guard listeningMode == .backgroundMusic else { return }
        Task { await request([0xE8, 0x09, Self.on, size.rawValue]) }
    }

    func setMode(_ newMode: NoiseMode) {
        mode = newMode
        sendNoiseSettings()
    }

    func setFocusOnVoice(_ on: Bool) {
        focusOnVoice = on
        sendNoiseSettings()
    }

    func commitAmbientLevel() {
        guard mode == .ambient else { return }
        sendNoiseSettings()
    }

    func commitVolume() {
        let level = UInt8(clamping: Int(volume.rounded()))
        Task { await request([0xA8, 0x20, min(level, 30)]) }
    }

    func setDSEE(_ on: Bool) {
        dsee = on
        Task { await request([0xE8, 0x01, on ? 1 : 0]) }
    }

    func setSpeakToChat(_ on: Bool) {
        speakToChat = on
        Task { await request([0xF8, 0x02, on ? 1 : 0, speakToChatSensitivity, speakToChatTimeout]) }
    }

    private func sendNoiseSettings() {
        let nc = mode == .noiseCancelling
        let ambient = mode == .ambient
        let level: UInt8 = ambient ? UInt8(clamping: Int(ambientLevel.rounded())) : 0x14
        let payload: [UInt8] = [
            0x68, 0x19, 0x01,
            nc || ambient ? 1 : 0,
            ambient ? 1 : 0,
            nc ? 1 : 0,
            min(level, 20),
            ambient && focusOnVoice ? 1 : 0,
            0x00,
        ]
        Task { await request(payload) }
    }

    @discardableResult
    private func request(_ payload: [UInt8], on dataType: UInt8 = Frame.dataMdr, timeout: Double = 3) async -> [UInt8]? {
        let previous = queueTail
        let task = Task { () -> [UInt8]? in
            await previous?.value
            return await self.transmit(payload, on: dataType, timeout: timeout)
        }
        queueTail = Task { _ = await task.value }
        return await task.value
    }

    private func transmit(_ payload: [UInt8], on dataType: UInt8, timeout: Double) async -> [UInt8]? {
        guard let channel, channel.isOpen(), let command = payload.first else { return nil }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            pending = (id, dataType, [command, command &+ 1], payload.count > 1 ? payload[1] : nil, continuation)
            let packet = Frame.pack(type: dataType, seq: seq, payload: payload)
            log.info("TX seq=\(self.seq, privacy: .public) \(Self.hex(payload), privacy: .public)")
            guard write(packet, to: channel) else {
                finish(id, with: nil)
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                if self.pending?.id == id {
                    self.log.info("No reply to \(Self.hex(payload), privacy: .public)")
                }
                self.finish(id, with: nil)
            }
        }
    }

    private func finish(_ id: UUID, with value: [UInt8]?) {
        guard let current = pending, current.id == id else { return }
        pending = nil
        current.done.resume(returning: value)
    }

    @discardableResult
    private func write(_ packet: [UInt8], to channel: IOBluetoothRFCOMMChannel) -> Bool {
        var bytes = packet
        let result = bytes.withUnsafeMutableBytes { buffer in
            channel.writeSync(buffer.baseAddress, length: UInt16(buffer.count))
        }
        if result != kIOReturnSuccess {
            log.error("RFCOMM write failed: \(result, privacy: .public)")
        }
        return result == kIOReturnSuccess
    }

    private func received(_ bytes: [UInt8]) {
        guard let channel else { return }
        for message in reader.feed(bytes) {
            let replySeq: UInt8 = message.seq <= 1 ? 1 - message.seq : 0
            write(Frame.pack(type: Frame.ack, seq: replySeq, payload: []), to: channel)
            if message.type == Frame.ack {
                seq = message.seq
                continue
            }
            guard let command = message.payload.first else { continue }
            log.info("RX \(message.type == Frame.dataMdr2 ? "T2 " : "", privacy: .public)\(Self.hex(message.payload), privacy: .public)")
            if message.type == Frame.dataMdr2 {
                applyPeripheral(message.payload)
            } else {
                apply(message.payload)
            }
            if let current = pending, current.dataType == message.type, current.expects.contains(command),
               current.type == nil || (message.payload.count > 1 && message.payload[1] == current.type) {
                finish(current.id, with: message.payload)
            }
        }
    }

    private func apply(_ p: [UInt8]) {
        switch p[0] {
        case 0x23:
            guard p.count >= 4 else { return }
            battery = Int(p[2])
            charging = p[3] != 0
        case 0x67, 0x69:
            guard p.count >= 8, p[1] == 0x19 else { return }
            let enabled = p[3] != 0
            let ambient = p[4] != 0
            mode = !enabled ? .off : (ambient ? .ambient : .noiseCancelling)
            if ambient {
                ambientLevel = Double(p[6])
                focusOnVoice = p[7] != 0
            }
        case 0xA7, 0xA9:
            guard p.count >= 3, p[1] == 0x20 else { return }
            volume = Double(p[2])
        case 0xE7, 0xE9:
            guard p.count >= 3 else { return }
            switch p[1] {
            case 0x01:
                dsee = p[2] != 0
            case 0x03, 0x09:
                if p[2] == Self.on {
                    listeningMode = .backgroundMusic
                } else if listeningMode == .backgroundMusic {
                    listeningMode = .standard
                }
                if p.count >= 4, let size = RoomSize(rawValue: p[3]) {
                    roomSize = size
                }
            case 0x04:
                if p[2] == Self.on {
                    listeningMode = .cinema
                } else if listeningMode == .cinema {
                    listeningMode = .standard
                }
            default:
                break
            }
        case 0xF7, 0xF9:
            guard p.count >= 3 else { return }
            speakToChat = p[2] != 0
            if p.count >= 5 {
                speakToChatSensitivity = p[3]
                speakToChatTimeout = p[4]
            }
        default:
            break
        }
    }

    private func reconnectAfterDrop() {
        let now = Date()
        recentReconnects = recentReconnects.filter { now.timeIntervalSince($0) < 60 } + [now]
        guard recentReconnects.count <= 3 else {
            log.info("Not reconnecting, too many drops in the last minute")
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await connect(userInitiated: false)
        }
    }

    private func applyPeripheral(_ p: [UInt8]) {
        guard p.count >= 3 else { return }
        switch (p[0], p[1]) {
        case (0x37, 0x00), (0x39, 0x00), (0x37, 0x02), (0x39, 0x02):
            if let parsed = Self.parseDevices(p, withClassOfDevice: p[1] == 0x02) {
                devices = parsed.sorted { ($0.connected ? 0 : 1, $0.name) < ($1.connected ? 0 : 1, $1.name) }
            }
        case (0x37, 0x01), (0x39, 0x01):
            playbackFixed = p[2] == 0x00
        case (0x3D, 0x01):
            guard p.count >= 20 else { return }
            let target = String(decoding: p[3..<20], as: UTF8.self)
            if p[2] == 0x00 {
                devices = devices.map {
                    PairedDevice(address: $0.address, name: $0.name, connected: $0.connected, playing: $0.address == target)
                }
            } else {
                switchFailure = Self.switchFailureMessage(p[2])
                Task { await refreshDevices() }
            }
        default:
            break
        }
    }

    private static func parseDevices(_ p: [UInt8], withClassOfDevice: Bool) -> [PairedDevice]? {
        var index = 2
        let count = Int(p[index])
        index += 1
        var entries: [(address: String, slot: UInt8, name: String)] = []
        for _ in 0..<count {
            guard index + 18 <= p.count else { return nil }
            let address = String(decoding: p[index..<(index + 17)], as: UTF8.self)
            let slot = p[index + 17]
            index += 18 + (withClassOfDevice ? 3 : 0)
            guard index < p.count else { return nil }
            let nameLength = Int(p[index])
            index += 1
            guard index + nameLength <= p.count else { return nil }
            let name = String(decoding: p[index..<(index + nameLength)], as: UTF8.self)
            index += nameLength
            entries.append((address, slot, name))
        }
        let playbackSlot: UInt8? = index < p.count ? p[index] : nil
        return entries.map {
            PairedDevice(
                address: $0.address,
                name: $0.name.isEmpty ? $0.address : $0.name,
                connected: $0.slot != 0,
                playing: $0.slot != 0 && $0.slot == playbackSlot
            )
        }
    }

    private static func switchFailureMessage(_ code: UInt8) -> String {
        switch code {
        case 0x02: "Couldn't switch while you're on a call."
        case 0x03: "Couldn't switch: that device isn't connected for audio."
        case 0x04: "Couldn't switch while a voice assistant is active."
        default: "The headphones didn't switch devices. Try again."
        }
    }

    private func tearDown() {
        channel = nil
        reader.reset()
        if let current = pending {
            pending = nil
            current.done.resume(returning: nil)
        }
    }

    private func resolveOpen(_ value: Bool) {
        guard let waiter = openWaiter else { return }
        openWaiter = nil
        waiter.resume(returning: value)
    }

    private func findDevice() -> IOBluetoothDevice? {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter(Self.isSonyHeadphones)
        return paired.first(where: { $0.isConnected() }) ?? paired.first
    }

    private static func isSonyHeadphones(_ device: IOBluetoothDevice) -> Bool {
        device.name?.contains("WH-1000XM6") == true
    }

    private func rfcommChannelID(on device: IOBluetoothDevice) async -> BluetoothRFCOMMChannelID {
        if let id = lookupChannel(on: device) { return id }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sdpWaiter = continuation
            if device.performSDPQuery(self) != kIOReturnSuccess {
                resolveSDP()
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.resolveSDP()
            }
        }
        return lookupChannel(on: device) ?? Self.fallbackChannel
    }

    private func resolveSDP() {
        guard let waiter = sdpWaiter else { return }
        sdpWaiter = nil
        waiter.resume()
    }

    private func lookupChannel(on device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID? {
        for bytes in Self.serviceUUIDs {
            let uuid = bytes.withUnsafeBytes { IOBluetoothSDPUUID(bytes: $0.baseAddress, length: $0.count) }
            guard let record = device.getServiceRecord(for: uuid) else { continue }
            var id: BluetoothRFCOMMChannelID = 0
            if record.getRFCOMMChannelID(&id) == kIOReturnSuccess {
                return id
            }
        }
        return nil
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

extension Headphones: IOBluetoothRFCOMMChannelDelegate {
    nonisolated func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let bytes = Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        MainActor.assumeIsolated { received(bytes) }
    }

    nonisolated func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        MainActor.assumeIsolated {
            if error == kIOReturnSuccess {
                channel = rfcommChannel
            } else {
                log.error("RFCOMM open failed: \(error, privacy: .public)")
            }
            resolveOpen(error == kIOReturnSuccess)
        }
    }

    nonisolated func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        MainActor.assumeIsolated {
            guard rfcommChannel === channel || channel == nil else { return }
            log.info("RFCOMM channel closed")
            resolveOpen(false)
            tearDown()
            guard status == .connected else { return }
            status = .disconnected
            reconnectAfterDrop()
        }
    }
}

extension Headphones {
    @objc nonisolated func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        MainActor.assumeIsolated { resolveSDP() }
    }
}
