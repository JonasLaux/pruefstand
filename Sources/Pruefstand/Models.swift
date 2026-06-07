import Foundation
import AppKit

/// CI rollup state for the latest commit on a PR.
enum CIState: String {
    case success
    case failure
    case pending
    case none

    init(rawRollup: String?) {
        switch rawRollup?.uppercased() {
        case "SUCCESS": self = .success
        case "FAILURE", "ERROR": self = .failure
        case "PENDING", "EXPECTED": self = .pending
        default: self = .none
        }
    }

    var symbolName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        case .none: return "minus.circle"
        }
    }

    var color: NSColor {
        switch self {
        case .success: return .systemGreen
        case .failure: return .systemRed
        case .pending: return .systemYellow
        case .none: return .secondaryLabelColor
        }
    }
}

/// A pull request that needs review. `id` is the PR url (globally unique).
struct PRDiffStats: Equatable {
    let additions: Int
    let deletions: Int
    let changedFiles: Int
}

struct PullRequest: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let repo: String
    let authorLogin: String
    let authorAvatarURL: String?
    let createdAt: Date
    let updatedAt: Date
    let reviewDecision: String?
    let commentCount: Int
    let ci: CIState
    let labels: [PRLabel]
    let diffStats: PRDiffStats
}

// MARK: - GraphQL response decoding

struct GQLResponse: Decodable {
    let data: DataField?
    let errors: [GQLError]?

    struct DataField: Decodable {
        let search: Search
    }
    struct Search: Decodable {
        let nodes: [Node]
    }
}

struct GQLError: Decodable {
    let message: String
}

/// One `search` node. Non-PR results (issues) decode with all fields nil because
/// the query uses an `... on PullRequest` inline fragment.
struct Node: Decodable {
    let number: Int?
    let title: String?
    let url: String?
    let createdAt: Date?
    let updatedAt: Date?
    let reviewDecision: String?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let repository: Repo?
    let author: Author?
    let comments: Comments?
    let commits: Commits?
    let labels: Labels?

    struct Repo: Decodable { let nameWithOwner: String }
    struct Author: Decodable { let login: String; let avatarUrl: String? }
    struct Comments: Decodable { let totalCount: Int }
    struct Labels: Decodable {
        let nodes: [LabelNode]
        struct LabelNode: Decodable {
            let name: String
            let color: String
        }
    }
    struct Commits: Decodable {
        let nodes: [CommitNode]
        struct CommitNode: Decodable {
            let commit: Commit
            struct Commit: Decodable {
                let statusCheckRollup: Rollup?
                struct Rollup: Decodable { let state: String }
            }
        }
    }

    /// Convert to a `PullRequest`, or nil if this node is not a usable PR.
    func toPullRequest() -> PullRequest? {
        guard let url, let number, let title, let createdAt, let updatedAt,
              let repository else { return nil }
        let rollup = commits?.nodes.first?.commit.statusCheckRollup?.state
        return PullRequest(
            id: url,
            number: number,
            title: title,
            url: url,
            repo: repository.nameWithOwner,
            authorLogin: author?.login ?? "unknown",
            authorAvatarURL: author?.avatarUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reviewDecision: reviewDecision,
            commentCount: comments?.totalCount ?? 0,
            ci: CIState(rawRollup: rollup),
            labels: labels?.nodes.map { PRLabel(name: $0.name, colorHex: $0.color) } ?? [],
            diffStats: PRDiffStats(
                additions: additions ?? 0,
                deletions: deletions ?? 0,
                changedFiles: changedFiles ?? 0
            )
        )
    }
}
