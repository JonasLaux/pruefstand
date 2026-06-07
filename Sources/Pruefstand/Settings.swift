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
    @Published var nudgeCommand: String { didSet { d.set(nudgeCommand, forKey: "nudgeCommand") } }
    @Published var urgentNudgeCommand: String { didSet { d.set(urgentNudgeCommand, forKey: "urgentNudgeCommand") } }

    init(userDefaults: UserDefaults = .standard) {
        d = userDefaults
        if d.object(forKey: "pollIntervalMinutes") == nil {
            // First launch defaults.
            pollIntervalMinutes = 5
            toggleDirect = false
            toggleTeams = true            // superset: covers direct + team requests
            toggleMentioned = false
            repoFilter = []
            tagFilters = []
            authorBlocklist = ["renovate", "dependabot", "github-actions"]
            sortKey = .created
            notificationsEnabled = true
            notificationsPaused = false
            seenPRIds = []
            nudgeCommand = ""
            urgentNudgeCommand = ""
        } else {
            pollIntervalMinutes = max(1, d.integer(forKey: "pollIntervalMinutes"))
            toggleDirect = d.bool(forKey: "toggleDirect")
            toggleTeams = d.bool(forKey: "toggleTeams")
            toggleMentioned = d.bool(forKey: "toggleMentioned")
            repoFilter = Set(d.stringArray(forKey: "repoFilter") ?? [])
            tagFilters = Set((d.stringArray(forKey: "tagFilters") ?? []).compactMap(TagFilter.init(rawValue:)))
            authorBlocklist = d.stringArray(forKey: "authorBlocklist") ?? []
            sortKey = SortKey(rawValue: d.string(forKey: "sortKey") ?? "created") ?? .created
            notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true
            notificationsPaused = d.bool(forKey: "notificationsPaused")
            seenPRIds = Set(d.stringArray(forKey: "seenPRIds") ?? [])
            nudgeCommand = d.string(forKey: "nudgeCommand") ?? ""
            urgentNudgeCommand = d.string(forKey: "urgentNudgeCommand") ?? ""
        }
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
        case .approve, .close:
            return nil
        }
    }

    /// True if the author should be hidden (explicit blocklist or any `[bot]` login).
    func isBlocked(author login: String) -> Bool {
        let lower = login.lowercased()
        if lower.hasSuffix("[bot]") { return true }
        return authorBlocklist.contains { lower == $0.lowercased() }
    }

    private func nonEmptyCommand(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
