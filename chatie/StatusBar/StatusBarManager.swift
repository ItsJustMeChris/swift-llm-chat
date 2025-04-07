import SwiftUI
import AppKit

class ChatWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var eventMonitor: EventMonitor?
    private var chatWindow: NSWindow?

    @Published var isPopoverOpen = false

    init() {
        setupStatusBar()
        setupEventMonitor()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Chat")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isPopoverOpen else { return }
            self.closePopover()
        }
        eventMonitor?.start()
    }

    @objc func togglePopover() {
        if isPopoverOpen {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let chatWindow = chatWindow {
            chatWindow.makeKeyAndOrderFront(nil)
            chatWindow.center()
            NSApp.activate(ignoringOtherApps: true)
            isPopoverOpen = true
            return
        }

        let window = ChatWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 650),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true

        window.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)

        let hostingController = NSHostingController(
            rootView: StatusBarChatView()
                .environmentObject(ModelManager.shared)
        )

        window.contentViewController = hostingController
        window.makeFirstResponder(hostingController.view)
        window.delegate = WindowDelegate(onClose: { [weak self] in
            self?.isPopoverOpen = false
        })

        window.center()
        window.makeKeyAndOrderFront(nil)
        chatWindow = window
        isPopoverOpen = true
    }

    func closePopover() {
        chatWindow?.close()
        chatWindow = nil
        isPopoverOpen = false
        eventMonitor?.stop()
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
