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
        button.image = makeMenuBarIcon()
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseDown])
        addHoverTracking(to: button)
    }

    private func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 26, height: 18)
        let noteRect = NSRect(x: 8, y: 2, width: 10, height: 14)
        // Asymmetric halo: music.note glyph sits towards the right of its bounds,
        // so expand more on the right to get an even gap all around the note.
        let haloRect = NSRect(x: noteRect.minX - 7, y: noteRect.minY - 7,
                              width: noteRect.width + 7 + 12, height: noteRect.height + 14)

        let result = NSImage(size: size, flipped: false) { _ in
            let brainCfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let haloCfg  = NSImage.SymbolConfiguration(pointSize: 15, weight: .black)
            let noteCfg  = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)

            // 1. Draw brain
            if let brain = NSImage(systemSymbolName: "brain.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(brainCfg) {
                brain.draw(in: NSRect(x: 0, y: 1, width: 26, height: 16))
            }
            // 2. Punch the note's silhouette (slightly enlarged) out of the brain
            if let halo = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
                    .withSymbolConfiguration(haloCfg) {
                halo.draw(in: haloRect, from: .zero, operation: .destinationOut, fraction: 1)
            }
            // 3. Draw the actual note on top
            if let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
                    .withSymbolConfiguration(noteCfg) {
                note.draw(in: noteRect, from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        result.isTemplate = true
        return result
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
        let reset = NSMenuItem(title: "Reset all ignored plugins", action: #selector(resetAllDismissals), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Forgotten Plugins", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func resetAllDismissals() {
        store.resetAllDismissals()
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
