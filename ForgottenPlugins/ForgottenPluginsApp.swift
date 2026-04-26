import ServiceManagement
import SwiftUI

@main
struct ForgottenPluginsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let store = PluginStore()
    private let preferences = Preferences()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(store: store, preferences: preferences)
        registerLoginItemIfNeeded()
    }

    private func registerLoginItemIfNeeded() {
        let key = "hasRegisteredLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        try? SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: key)
    }
}
