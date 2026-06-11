import AppKit
import SwiftUI
import Combine

/// A borderless panel that can become key so SwiftUI controls (text fields,
/// menus) work inside it.
final class PRPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the status item, the dropdown panel, the right-click menu, and the
/// settings window.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let panel: PRPanel
    private let store: PRStore
    private let settings: Settings
    private let actionMode: PRActionMode

    var onRefresh: () -> Void = {}
    var onPopoverState: (Bool) -> Void = { _ in }
    var onPRAction: (PRAction, PullRequest) -> Void = { _, _ in }

    private let panelWidth: CGFloat = PopoverLayout.width
    private let panelHeight: CGFloat
    private var settingsWindow: NSWindow?
    private var clickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init(store: PRStore, settings: Settings, actionMode: PRActionMode) {
        self.store = store
        self.settings = settings
        self.actionMode = actionMode
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let available = (NSScreen.main?.visibleFrame.height ?? 600) - 24
        self.panelHeight = min(440, max(280, available))

        self.panel = PRPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        super.init()

        configurePanel()
        configureButton()

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)
        updateBadge()
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Pruefstand")
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self

        let root = PopoverView(
            store: store,
            settings: settings,
            height: panelHeight,
            actionMode: actionMode,
            onRefresh: { [weak self] in self?.onRefresh() },
            onPRAction: { [weak self] action, pr in self?.onPRAction(action, pr) },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hosting
    }

    private func updateBadge() {
        let count = store.displayed(for: .reviewNeeded).count
        statusItem.button?.title = count > 0 ? " \(count)" : ""
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // Status-item window frame in screen coordinates; its bottom edge is the
        // bottom of the menu bar.
        let anchor = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var x = anchor.midX - panelWidth / 2
        // Keep on-screen horizontally.
        x = max(visible.minX + 8, min(x, visible.maxX - panelWidth - 8))
        let y = anchor.minY - panelHeight - 4

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installClickMonitor()
        onPopoverState(true)
    }

    private func closePanel() {
        panel.orderOut(nil)
        removeClickMonitor()
        onPopoverState(false)
    }

    /// Close the panel when the user clicks anywhere outside it.
    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func removeClickMonitor() {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel {
            closePanel()
        }
    }

    // MARK: - Right-click menu

    private func showMenu() {
        let menu = NSMenu()
        let pauseTitle = settings.notificationsPaused ? "Resume notifications" : "Pause notifications"
        menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(withTitle: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() { settings.notificationsPaused.toggle() }
    @objc private func refreshNow() { onRefresh() }
    @objc private func openSettingsMenu() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Settings window

    private func openSettings() {
        closePanel()
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView(settings: settings, onApply: { [weak self] in self?.onRefresh() })
        )
        let win = NSWindow(contentViewController: hosting)
        win.title = "Pruefstand Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        settingsWindow = win
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
