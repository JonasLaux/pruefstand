import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let actionMode: PRActionMode
    private let settings = Settings()
    private lazy var store = PRStore(settings: settings)
    private let notifier = NotificationManager()
    private let client = GHClient()
    private let commandRunner = PRCommandRunner()
    private var menuBar: MenuBarController!
    private var poller: Poller!

    init(actionMode: PRActionMode) {
        self.actionMode = actionMode
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()

        poller = Poller(store: store, settings: settings, notifier: notifier)

        menuBar = MenuBarController(store: store, settings: settings, actionMode: actionMode)
        menuBar.onRefresh = { [weak self] in self?.poller.refreshNow() }
        menuBar.onPopoverState = { [weak self] open in self?.poller.setPopoverOpen(open) }
        menuBar.onPRAction = { [weak self] action, pr in self?.perform(action, on: pr) }

        poller.start()
    }

    private func perform(_ action: PRAction, on pr: PullRequest) {
        if case .running = store.actionStatuses[pr.id] { return }
        let command = settings.command(for: action)
        store.beginAction(action, for: pr)

        Task {
            do {
                if actionMode == .dryRun {
                    try await Task.sleep(for: .milliseconds(500))
                } else if action.isGitHubMutation {
                    try await client.perform(action: action, onURL: pr.url)
                } else if let command {
                    try await commandRunner.run(command: command, for: pr)
                } else {
                    throw PRCommandError(message: "No command configured")
                }

                await MainActor.run {
                    store.finishAction(action, for: pr, dryRun: actionMode == .dryRun)
                    if actionMode == .live, action.removesPRFromListOnSuccess {
                        store.remove(id: pr.id)
                    }
                }
            } catch {
                await MainActor.run {
                    let message = (error as? GHError)?.message ?? error.localizedDescription
                    store.failAction(action, for: pr, message: message)
                }
            }
        }
    }
}
