import Foundation
import Combine

/// Single source of truth for the UI. Holds the raw fetched list and exposes a
/// derived (filtered + sorted) list.
@MainActor
final class PRStore: ObservableObject {
    @Published private(set) var raw: [PullRequest] = []
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

    func setRaw(_ prs: [PullRequest]) {
        raw = prs
    }

    func remove(id: String) {
        raw.removeAll { $0.id == id }
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
        Array(Set(raw.map(\.repo))).sorted()
    }

    var availableLabels: [PRLabel] {
        let byName = Dictionary(grouping: raw.flatMap(\.labels), by: { $0.name.lowercased() })
        return byName.values
            .compactMap { $0.first }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var availableTagPrefixes: [TagFilter] {
        TagFilter.prefixOptions(from: availableLabels)
    }

    /// Filtered + sorted list shown in the UI.
    var displayed: [PullRequest] {
        var list = raw.filter { !settings.isBlocked(author: $0.authorLogin) }
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
