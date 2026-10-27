import AppKit
import SwiftUI

struct TopAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> TopAnchorView { TopAnchorView() }
    func updateNSView(_ nsView: TopAnchorView, context: Context) {}
}

final class TopAnchorView: NSView {
    private var token: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
        guard let window else { return }
        token = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated { TopAnchorView.pin(window) }
        }
    }

    static func pin(_ window: NSWindow) {
        let menuBarBottom = NSApp.windows
            .first { String(describing: type(of: $0)).contains("StatusBar") && $0.screen == window.screen }?
            .frame.minY ?? window.screen?.visibleFrame.maxY
        guard let menuBarBottom else { return }
        let top = menuBarBottom - 2
        guard abs(window.frame.maxY - top) > 0.5 else { return }
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
    }
}
