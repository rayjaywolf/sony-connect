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
        guard !pinning, let window, let top = menuBarBottom(for: window) else { return }
        guard abs(window.frame.maxY - top) > 0.5 else { return }
        pinning = true
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
        pinning = false
    }

    private func menuBarBottom(for window: NSWindow) -> CGFloat? {
        let statusBar = NSApp.windows.first {
            $0 !== window && String(describing: type(of: $0)).contains("StatusBar") && $0.screen == window.screen
        }
        if let statusBar { return statusBar.frame.minY - 2 }
        guard let screen = window.screen else { return nil }
        return screen.frame.maxY - (NSStatusBar.system.thickness) - 2
    }
}
