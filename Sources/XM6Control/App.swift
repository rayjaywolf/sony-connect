import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let headphones = Headphones()
    let loginItem = LoginItem()
    let panelState = PanelState()

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
            Panel(headphones: delegate.headphones, loginItem: delegate.loginItem, state: delegate.panelState)
        } label: {
            Image(systemName: "headphones")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class PanelState: ObservableObject {
    @Published var equalizerOpen = false
    @Published var devicesOpen = false
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
