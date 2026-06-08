import Foundation

enum SortKey: String, CaseIterable {
    case created, updated, repo, ciState

    var label: String {
        switch self {
        case .created: return "Created"
        case .updated: return "Updated"
        case .repo: return "Repo"
        case .ciState: return "CI"
        }
    }
}

enum PRIgnoreKey {
    static func make(repo: String, number: Int) -> String {
        "\(repo)#\(number)"
    }
}

/// User-configurable settings, persisted to `UserDefaults`.
@MainActor
final class Settings: ObservableObject {
    private let d: UserDefaults

    @Published var pollIntervalMinutes: Int { didSet { d.set(pollIntervalMinutes, forKey: "pollIntervalMinutes") } }
    @Published var toggleDirect: Bool { didSet { d.set(toggleDirect, forKey: "toggleDirect") } }
    @Published var toggleTeams: Bool { didSet { d.set(toggleTeams, forKey: "toggleTeams") } }
    @Published var toggleMentioned: Bool { didSet { d.set(toggleMentioned, forKey: "toggleMentioned") } }
    @Published var repoFilter: Set<String> { didSet { d.set(Array(repoFilter), forKey: "repoFilter") } }
    @Published var tagFilters: Set<TagFilter> { didSet { d.set(tagFilters.map(\.rawValue), forKey: "tagFilters") } }
    @Published var authorBlocklist: [String] { didSet { d.set(authorBlocklist, forKey: "authorBlocklist") } }
    @Published var sortKey: SortKey { didSet { d.set(sortKey.rawValue, forKey: "sortKey") } }
    @Published var notificationsEnabled: Bool { didSet { d.set(notificationsEnabled, forKey: "notificationsEnabled") } }
    @Published var notificationsPaused: Bool { didSet { d.set(notificationsPaused, forKey: "notificationsPaused") } }
    @Published var seenPRIds: Set<String> { didSet { d.set(Array(seenPRIds), forKey: "seenPRIds") } }
    @Published var ignoredPRKeys: Set<String> { didSet { d.set(Array(ignoredPRKeys), forKey: "ignoredPRKeys") } }
    @Published var nudgeCommand: String { didSet { d.set(nudgeCommand, forKey: "nudgeCommand") } }
    @Published var urgentNudgeCommand: String { didSet { d.set(urgentNudgeCommand, forKey: "urgentNudgeCommand") } }

    init(userDefaults: UserDefaults = .standard) {
        d = userDefaults
        pollIntervalMinutes = max(1, d.object(forKey: "pollIntervalMinutes") as? Int ?? 5)
        toggleDirect = d.object(forKey: "toggleDirect") as? Bool ?? false
        toggleTeams = d.object(forKey: "toggleTeams") as? Bool ?? true
        toggleMentioned = d.object(forKey: "toggleMentioned") as? Bool ?? false
        repoFilter = Set(d.stringArray(forKey: "repoFilter") ?? [])
        tagFilters = Set((d.stringArray(forKey: "tagFilters") ?? []).compactMap(TagFilter.init(rawValue:)))
        authorBlocklist = d.stringArray(forKey: "authorBlocklist") ?? ["renovate", "dependabot", "github-actions"]
        sortKey = SortKey(rawValue: d.string(forKey: "sortKey") ?? "created") ?? .created
        notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true
        notificationsPaused = d.object(forKey: "notificationsPaused") as? Bool ?? false
        seenPRIds = Set(d.stringArray(forKey: "seenPRIds") ?? [])
        ignoredPRKeys = Set(d.stringArray(forKey: "ignoredPRKeys") ?? [])
        nudgeCommand = d.string(forKey: "nudgeCommand") ?? ""
        urgentNudgeCommand = d.string(forKey: "urgentNudgeCommand") ?? ""
    }

    var availableCommandActions: [PRAction] {
        [.nudge, .urgentNudge].filter { command(for: $0) != nil }
    }

    func command(for action: PRAction) -> String? {
        switch action {
        case .nudge:
            return nonEmptyCommand(nudgeCommand)
        case .urgentNudge:
            return nonEmptyCommand(urgentNudgeCommand)
        case .ignore, .approve, .close:
            return nil
        }
    }

    /// True if the author should be hidden (explicit blocklist or any `[bot]` login).
    func isBlocked(author login: String) -> Bool {
        let lower = login.lowercased()
        if lower.hasSuffix("[bot]") { return true }
        return authorBlocklist.contains { lower == $0.lowercased() }
    }

    func isIgnored(repo: String, number: Int) -> Bool {
        ignoredPRKeys.contains(PRIgnoreKey.make(repo: repo, number: number))
    }

    func ignore(repo: String, number: Int) {
        ignoredPRKeys.insert(PRIgnoreKey.make(repo: repo, number: number))
    }

    func clearIgnoredPRs() {
        ignoredPRKeys = []
    }

    private func nonEmptyCommand(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
