import Foundation

enum PRAction: Equatable, Hashable {
    case ignore
    case approve
    case close
    case nudge
    case urgentNudge

    var label: String {
        switch self {
        case .ignore: return "Ignore"
        case .approve: return "Approve"
        case .close: return "Close"
        case .nudge: return "Nudge"
        case .urgentNudge: return "Urgent nudge"
        }
    }

    var promptTitle: String {
        switch self {
        case .ignore: return "Ignore this PR?"
        case .approve: return "Approve this PR?"
        case .close: return "Close this PR?"
        case .nudge: return "Run nudge?"
        case .urgentNudge: return "Run urgent nudge?"
        }
    }

    var promptDetail: String {
        switch self {
        case .ignore: return "Hide locally by repo and PR number."
        case .approve: return "Submit an approval review."
        case .close: return "Close without merging."
        case .nudge: return "Run your configured nudge command."
        case .urgentNudge: return "Run your configured urgent nudge command."
        }
    }

    var dryRunDetail: String {
        switch self {
        case .ignore: return "Debug mode: no local ignore will be saved."
        case .approve, .close: return "Debug mode: no GitHub action will be sent."
        case .nudge, .urgentNudge: return "Debug mode: no command will be run."
        }
    }

    var successMessage: String {
        switch self {
        case .ignore: return "Ignored"
        case .approve: return "Approved"
        case .close: return "Closed"
        case .nudge: return "Nudged"
        case .urgentNudge: return "Urgent nudge sent"
        }
    }

    var progressMessage: String {
        switch self {
        case .ignore: return "Ignoring..."
        case .approve: return "Approving..."
        case .close: return "Closing..."
        case .nudge: return "Nudging..."
        case .urgentNudge: return "Urgent nudge..."
        }
    }

    var systemImage: String {
        switch self {
        case .ignore: return "eye.slash"
        case .approve: return "checkmark"
        case .close: return "xmark"
        case .nudge: return "bell"
        case .urgentNudge: return "exclamationmark.bubble"
        }
    }

    var isGitHubMutation: Bool {
        switch self {
        case .approve, .close: return true
        case .ignore, .nudge, .urgentNudge: return false
        }
    }

    var removesPRFromListOnSuccess: Bool {
        switch self {
        case .approve, .close: return true
        case .ignore, .nudge, .urgentNudge: return false
        }
    }

    func ghArguments(for url: String) -> [String] {
        switch self {
        case .approve:
            return ["pr", "review", url, "--approve"]
        case .close:
            return ["pr", "close", url]
        case .ignore, .nudge, .urgentNudge:
            preconditionFailure("\(label) is a local command action, not a gh action")
        }
    }
}

enum PRActionMode: Equatable {
    case live
    case dryRun
}

enum PRActionStatus: Equatable {
    case running(PRAction)
    case succeeded(PRAction, dryRun: Bool)
    case failed(PRAction, message: String)
}
