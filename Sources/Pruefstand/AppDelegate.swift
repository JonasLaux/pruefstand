import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private lazy var store = PRStore(settings: settings)
    private let notifier = NotificationManager()
    private var menuBar: MenuBarController!
    private var poller: Poller!

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()

        poller = Poller(store: store, settings: settings, notifier: notifier)

        menuBar = MenuBarController(store: store, settings: settings)
        menuBar.onRefresh = { [weak self] in self?.poller.refreshNow() }
        menuBar.onPopoverState = { [weak self] open in self?.poller.setPopoverOpen(open) }

        poller.start()
    }
}
