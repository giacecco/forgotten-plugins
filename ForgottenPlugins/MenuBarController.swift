import AppKit
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store: PluginStore
    private let preferences: Preferences
    private var mouseMonitor: Timer?

    init(store: PluginStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        super.init()
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Forgotten Plugins")
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseDown])
        addHoverTracking(to: button)
    }

    private func addHoverTracking(to button: NSStatusBarButton) {
        let area = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(area)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .aqua)
        let vc = FixedSizeHostingController(
            rootView: PopoverView(store: store, preferences: preferences),
            size: NSSize(width: 320, height: 440)
        )
        vc.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        popover.contentViewController = vc
    }

    func mouseEntered(with event: NSEvent) {
        guard !popover.isShown else { return }
        showPopover()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseDown {
            showContextMenu()
        } else if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Forgotten Plugins", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.refresh()
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        lockPopoverWindowSize()
        startMouseMonitor()
    }

    private func lockPopoverWindowSize() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.popover.contentViewController?.view.window else { return }
            let size = NSSize(width: 320, height: 440)
            window.minSize = size
            window.maxSize = size
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopMouseMonitor()
    }

    // MARK: - Hover-away close

    private func startMouseMonitor() {
        mouseMonitor?.invalidate()
        mouseMonitor = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.checkMouseProximity()
        }
    }

    private func stopMouseMonitor() {
        mouseMonitor?.invalidate()
        mouseMonitor = nil
    }

    private func checkMouseProximity() {
        guard popover.isShown else { stopMouseMonitor(); return }
        let mouse = NSEvent.mouseLocation
        let buttonFrame = statusItem.button?.window?.frame ?? .zero
        let popoverFrame = popover.contentViewController?.view.window?.frame ?? .zero
        if !buttonFrame.union(popoverFrame).contains(mouse) {
            closePopover()
        }
    }
}
