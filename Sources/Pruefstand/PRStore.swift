import Foundation
import Combine

/// Single source of truth for the UI. Holds the raw fetched lists and exposes
/// derived (filtered + sorted) lists.
@MainActor
final class PRStore: ObservableObject {
    @Published private(set) var rawByTab: [PullRequestTab: [PullRequest]] = [:]
    @Published var lastError: String?
    @Published var isLoading = false
    @Published private(set) var actionStatuses: [String: PRActionStatus] = [:]

    let settings: Settings
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        // Re-publish when settings (filters/sort) change so views recompute.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var raw: [PullRequest] {
        raw(for: .reviewNeeded)
    }

    func raw(for tab: PullRequestTab) -> [PullRequest] {
        rawByTab[tab] ?? []
    }

    func setRaw(_ prs: [PullRequest]) {
        setRaw(prs, for: .reviewNeeded)
    }

    func setRaw(_ prs: [PullRequest], for tab: PullRequestTab) {
        rawByTab[tab] = prs
    }

    func setFetched(_ result: PRFetchResult) {
        for tab in PullRequestTab.allCases {
            rawByTab[tab] = result.pullRequests(for: tab)
        }
    }

    func remove(id: String) {
        for tab in PullRequestTab.allCases {
            rawByTab[tab]?.removeAll { $0.id == id }
        }
        actionStatuses[id] = nil
    }

    func beginAction(_ action: PRAction, for pr: PullRequest) {
        actionStatuses[pr.id] = .running(action)
    }

    func finishAction(_ action: PRAction, for pr: PullRequest, dryRun: Bool) {
        actionStatuses[pr.id] = .succeeded(action, dryRun: dryRun)
    }

    func failAction(_ action: PRAction, for pr: PullRequest, message: String) {
        actionStatuses[pr.id] = .failed(action, message: message)
    }

    /// Repos present in the current results, sorted.
    var availableRepos: [String] {
        availableRepos(for: .reviewNeeded)
    }

    func availableRepos(for tab: PullRequestTab) -> [String] {
        Array(Set(raw(for: tab).map(\.repo))).sorted()
    }

    var availableLabels: [PRLabel] {
        availableLabels(for: .reviewNeeded)
    }

    func availableLabels(for tab: PullRequestTab) -> [PRLabel] {
        let byName = Dictionary(grouping: raw(for: tab).flatMap(\.labels), by: { $0.name.lowercased() })
        return byName.values
            .compactMap { $0.first }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var availableTagPrefixes: [TagFilter] {
        availableTagPrefixes(for: .reviewNeeded)
    }

    func availableTagPrefixes(for tab: PullRequestTab) -> [TagFilter] {
        TagFilter.prefixOptions(from: availableLabels(for: tab))
    }

    /// Filtered + sorted list shown in the UI.
    var displayed: [PullRequest] {
        displayed(for: .reviewNeeded)
    }

    func displayed(for tab: PullRequestTab) -> [PullRequest] {
        var list = raw(for: tab).filter { !settings.isBlocked(author: $0.authorLogin) && !settings.isIgnored($0) }
        if !settings.repoFilter.isEmpty {
            list = list.filter { settings.repoFilter.contains($0.repo) }
        }
        if !settings.tagFilters.isEmpty {
            list = list.filter { TagFilter.matchesAny(settings.tagFilters, labels: $0.labels) }
        }
        switch settings.sortKey {
        case .created:
            list.sort { $0.createdAt > $1.createdAt }
        case .updated:
            list.sort { $0.updatedAt > $1.updatedAt }
        case .repo:
            list.sort { $0.repo.localizedCaseInsensitiveCompare($1.repo) == .orderedAscending }
        case .ciState:
            list.sort { ciRank($0.ci) < ciRank($1.ci) }
        }
        return list
    }

    private func ciRank(_ s: CIState) -> Int {
        switch s {
        case .failure: return 0
        case .pending: return 1
        case .none: return 2
        case .success: return 3
        }
    }
}
