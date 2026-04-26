import AppKit
import SwiftUI

// NSHostingController bypasses preferredContentSize by directly resizing its view,
// which causes NSPopover to animate a resize whenever SwiftUI re-measures content.
// This wrapper fixes that: a plain NSViewController owns the fixed-size root view;
// the hosting controller is a child pinned to fill it by constraints, forcing
// SwiftUI to lay out within the fixed bounds rather than driving the window size.
final class FixedSizeHostingController<Content: View>: NSViewController {
    private let fixedSize: NSSize
    private let hostingController: NSHostingController<Content>

    init(rootView: Content, size: NSSize) {
        self.fixedSize = size
        self.hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: fixedSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    override var preferredContentSize: NSSize {
        get { fixedSize }
        set { }
    }
}
