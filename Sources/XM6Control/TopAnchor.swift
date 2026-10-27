import AppKit
import SwiftUI

struct TopAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> TopAnchorView { TopAnchorView() }
    func updateNSView(_ nsView: TopAnchorView, context: Context) {
        nsView.schedulePin()
    }
}

final class TopAnchorView: NSView {
    private var tokens: [NSObjectProtocol] = []
    private var pinning = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens.removeAll()
        guard let window else { return }
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedulePin() }
            })
        }
        schedulePin()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        schedulePin()
    }

    func schedulePin() {
        pin()
        DispatchQueue.main.async { [weak self] in self?.pin() }
    }

    private func pin() {
        guard !pinning, let window else { return }
        let statusItem = statusItemWindow(for: window)
        guard let top = statusItem.map({ $0.frame.minY - 2 }) ?? window.screen.map({ $0.frame.maxY - NSStatusBar.system.thickness - 2 }) else { return }
        let height = (bounds.height * 2).rounded() / 2
        guard height > 1 else { return }
        let width = window.frame.width
        var x = window.frame.minX
        if let statusItem {
            x = (statusItem.frame.midX - width / 2).rounded()
            if let screen = statusItem.screen ?? window.screen {
                let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 0)
                x = min(max(x, bounds.minX), bounds.maxX - width)
            }
        }
        let target = NSRect(x: x, y: top - height, width: width, height: height)
        guard abs(window.frame.minX - x) > 0.5 || abs(window.frame.maxY - top) > 0.5 || abs(window.frame.height - height) > 0.5 else { return }
        pinning = true
        window.setFrame(target, display: true, animate: false)
        pinning = false
    }

    private func statusItemWindow(for window: NSWindow) -> NSWindow? {
        NSApp.windows.first {
            $0 !== window && String(describing: type(of: $0)).contains("StatusBar") && $0.frame.width < 200
        }
    }
}
