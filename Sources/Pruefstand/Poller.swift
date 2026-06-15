import Foundation
import Combine

/// Drives refresh: a main timer on the configured interval, plus a fast timer
/// that only runs while the popover is open (to watch CI move).
@MainActor
final class Poller {
    private let store: PRStore
    private let settings: Settings
    private let notifier: NotificationManager
    private let client = GHClient()

    private var mainTimer: Timer?
    private var fastTimer: Timer?
    private var popoverOpen = false
    private var refreshing = false
    private var cancellables = Set<AnyCancellable>()

    private let fastInterval: TimeInterval = 30

    init(store: PRStore, settings: Settings, notifier: NotificationManager) {
        self.store = store
        self.settings = settings
        self.notifier = notifier

        // Reschedule the main timer whenever the interval changes.
        settings.$pollIntervalMinutes
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleMain() }
            .store(in: &cancellables)
    }

    func start() {
        scheduleMain()
        refreshNow()
    }

    func refreshNow() {
        Task { await refresh() }
    }

    func setPopoverOpen(_ open: Bool) {
        popoverOpen = open
        if open {
            refreshNow()
            fastTimer?.invalidate()
            fastTimer = Timer.scheduledTimer(withTimeInterval: fastInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshNow()
                }
            }
        } else {
            fastTimer?.invalidate()
            fastTimer = nil
        }
    }

    private func scheduleMain() {
        mainTimer?.invalidate()
        let interval = TimeInterval(max(1, settings.pollIntervalMinutes) * 60)
        mainTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
    }

    private func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }

        store.isLoading = true
        do {
            let result = try await client.fetch(
                direct: settings.toggleDirect,
                teams: settings.toggleTeams,
                mentioned: settings.toggleMentioned,
                includeDrafts: settings.includeDrafts,
                watchedRepos: settings.repoFilter,
                watchedContributors: settings.watchedContributors
            )
            store.setFetched(result)
            store.lastError = nil
            notifier.process(current: store.displayed(for: .reviewNeeded), settings: settings)
        } catch {
            store.lastError = (error as? GHError)?.message ?? error.localizedDescription
        }
        store.isLoading = false
    }
}
