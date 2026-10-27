import Foundation

enum Frame {
    static let start: UInt8 = 0x3E
    static let end: UInt8 = 0x3C
    static let escape: UInt8 = 0x3D
    static let ack: UInt8 = 0x01
    static let dataMdr: UInt8 = 0x0C
    static let dataMdr2: UInt8 = 0x0E

    struct Message {
        let type: UInt8
        let seq: UInt8
        let payload: [UInt8]
    }

    static func pack(type: UInt8, seq: UInt8, payload: [UInt8]) -> [UInt8] {
        let length = UInt32(payload.count)
        var inner: [UInt8] = [
            type, seq,
            UInt8(truncatingIfNeeded: length >> 24),
            UInt8(truncatingIfNeeded: length >> 16),
            UInt8(truncatingIfNeeded: length >> 8),
            UInt8(truncatingIfNeeded: length),
        ] + payload
        inner.append(checksum(inner))
        var out: [UInt8] = [start]
        for byte in inner {
            if byte == start || byte == end || byte == escape {
                out.append(escape)
                out.append(byte & 0xEF)
            } else {
                out.append(byte)
            }
        }
        out.append(end)
        return out
    }

    static func checksum<S: Sequence>(_ bytes: S) -> UInt8 where S.Element == UInt8 {
        bytes.reduce(0) { $0 &+ $1 }
    }

    static func unpack(_ escaped: ArraySlice<UInt8>) -> Message? {
        var inner: [UInt8] = []
        var iterator = escaped.makeIterator()
        while let byte = iterator.next() {
            if byte == escape, let next = iterator.next() {
                inner.append(next | 0x10)
            } else {
                inner.append(byte)
            }
        }
        guard inner.count >= 7, checksum(inner.dropLast()) == inner.last else { return nil }
        let length = Int(inner[2]) << 24 | Int(inner[3]) << 16 | Int(inner[4]) << 8 | Int(inner[5])
        guard inner.count == 7 + length else { return nil }
        return Message(type: inner[0], seq: inner[1], payload: Array(inner[6..<(6 + length)]))
    }
}

struct FrameReader {
    private var buffer: [UInt8] = []

    mutating func reset() {
        buffer.removeAll()
    }

    mutating func feed(_ bytes: [UInt8]) -> [Frame.Message] {
        buffer += bytes
        var messages: [Frame.Message] = []
        while let startIndex = buffer.firstIndex(of: Frame.start) {
            guard let endIndex = buffer[(startIndex + 1)...].firstIndex(of: Frame.end) else {
                buffer.removeFirst(startIndex)
                return messages
            }
            if let message = Frame.unpack(buffer[(startIndex + 1)..<endIndex]) {
                messages.append(message)
            }
            buffer.removeFirst(endIndex + 1)
        }
        buffer.removeAll()
        return messages
    }
}
