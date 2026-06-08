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

struct FailedCICheck: Equatable, Identifiable {
    var id: String { name }

    let name: String
}

struct ReviewThreadAuthorCount: Equatable, Identifiable {
    var id: String { author }

    let author: String
    let count: Int

    static func grouped(from authors: [String]) -> [ReviewThreadAuthorCount] {
        var buckets: [String: (author: String, count: Int)] = [:]
        for author in authors {
            let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            var bucket = buckets[key] ?? (author: trimmed, count: 0)
            bucket.count += 1
            buckets[key] = bucket
        }
        return buckets.values
            .map { ReviewThreadAuthorCount(author: $0.author, count: $0.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending
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
    let reviewCommentCount: Int
    let unresolvedReviewThreadsByAuthor: [ReviewThreadAuthorCount]
    let ci: CIState
    let failedCIChecks: [FailedCICheck]
    let labels: [PRLabel]
    let diffStats: PRDiffStats

    init(
        id: String,
        number: Int,
        title: String,
        url: String,
        repo: String,
        authorLogin: String,
        authorAvatarURL: String?,
        createdAt: Date,
        updatedAt: Date,
        reviewDecision: String?,
        commentCount: Int,
        reviewCommentCount: Int = 0,
        unresolvedReviewThreadsByAuthor: [ReviewThreadAuthorCount] = [],
        ci: CIState,
        failedCIChecks: [FailedCICheck] = [],
        labels: [PRLabel],
        diffStats: PRDiffStats
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.repo = repo
        self.authorLogin = authorLogin
        self.authorAvatarURL = authorAvatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reviewDecision = reviewDecision
        self.commentCount = commentCount
        self.reviewCommentCount = reviewCommentCount
        self.unresolvedReviewThreadsByAuthor = unresolvedReviewThreadsByAuthor
        self.ci = ci
        self.failedCIChecks = failedCIChecks
        self.labels = labels
        self.diffStats = diffStats
    }
}

extension PullRequest {
    var totalCommentCount: Int {
        commentCount + reviewCommentCount
    }

    var unresolvedReviewThreadCount: Int {
        unresolvedReviewThreadsByAuthor.reduce(0) { $0 + $1.count }
    }

    var unresolvedReviewThreadsTooltip: String {
        guard !unresolvedReviewThreadsByAuthor.isEmpty else {
            return "No unresolved review comments"
        }
        return (
            ["Unresolved review comments"] +
                unresolvedReviewThreadsByAuthor.map { "- \($0.count) \($0.author)" }
        ).joined(separator: "\n")
    }

    var failedCIChecksTooltip: String {
        guard !failedCIChecks.isEmpty else {
            return "CI failed"
        }
        return (
            ["Failed CI pipelines"] +
                failedCIChecks.map { "- \($0.name)" }
        ).joined(separator: "\n")
    }

    var ciTooltip: String {
        switch ci {
        case .success:
            return "CI passed"
        case .failure:
            return failedCIChecksTooltip
        case .pending:
            return "CI pending"
        case .none:
            return "No CI status"
        }
    }
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
    let reviewThreads: ReviewThreads?
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
    struct ReviewThreads: Decodable {
        let nodes: [ReviewThreadNode]

        var reviewCommentCount: Int {
            nodes.reduce(0) { $0 + $1.comments.totalCount }
        }

        var unresolvedAuthorCounts: [ReviewThreadAuthorCount] {
            ReviewThreadAuthorCount.grouped(
                from: nodes
                    .filter { !$0.isResolved }
                    .map { $0.comments.nodes.first?.author?.login ?? "unknown" }
            )
        }

        struct ReviewThreadNode: Decodable {
            let isResolved: Bool
            let comments: ReviewThreadComments

            struct ReviewThreadComments: Decodable {
                let totalCount: Int
                let nodes: [ReviewCommentNode]

                struct ReviewCommentNode: Decodable {
                    let author: Node.Author?
                }
            }
        }
    }
    struct Commits: Decodable {
        let nodes: [CommitNode]
        struct CommitNode: Decodable {
            let commit: Commit
            struct Commit: Decodable {
                let statusCheckRollup: Rollup?
                struct Rollup: Decodable {
                    let state: String
                    let contexts: StatusCheckContexts?

                    struct StatusCheckContexts: Decodable {
                        let nodes: [StatusCheckContext]

                        var failedChecks: [FailedCICheck] {
                            nodes.compactMap(\.failedCheck)
                        }
                    }

                    enum StatusCheckContext: Decodable {
                        case checkRun(name: String, conclusion: String?)
                        case statusContext(context: String, state: String?)
                        case unknown

                        private enum CodingKeys: String, CodingKey {
                            case typeName = "__typename"
                            case name
                            case conclusion
                            case context
                            case state
                        }

                        init(from decoder: Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            let typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
                            switch typeName {
                            case "CheckRun":
                                self = .checkRun(
                                    name: try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed check",
                                    conclusion: try container.decodeIfPresent(String.self, forKey: .conclusion)
                                )
                            case "StatusContext":
                                self = .statusContext(
                                    context: try container.decodeIfPresent(String.self, forKey: .context) ?? "Unnamed status",
                                    state: try container.decodeIfPresent(String.self, forKey: .state)
                                )
                            default:
                                self = .unknown
                            }
                        }

                        var failedCheck: FailedCICheck? {
                            switch self {
                            case .checkRun(let name, let conclusion):
                                return Self.isFailure(conclusion) ? FailedCICheck(name: name) : nil
                            case .statusContext(let context, let state):
                                return Self.isFailure(state) ? FailedCICheck(name: context) : nil
                            case .unknown:
                                return nil
                            }
                        }

                        private static func isFailure(_ value: String?) -> Bool {
                            switch value?.uppercased() {
                            case "ACTION_REQUIRED", "CANCELLED", "ERROR", "FAILURE", "STARTUP_FAILURE", "TIMED_OUT":
                                return true
                            default:
                                return false
                            }
                        }
                    }
                }
            }
        }
    }

    /// Convert to a `PullRequest`, or nil if this node is not a usable PR.
    func toPullRequest() -> PullRequest? {
        guard let url, let number, let title, let createdAt, let updatedAt,
              let repository else { return nil }
        let rollup = commits?.nodes.first?.commit.statusCheckRollup
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
            reviewCommentCount: reviewThreads?.reviewCommentCount ?? 0,
            unresolvedReviewThreadsByAuthor: reviewThreads?.unresolvedAuthorCounts ?? [],
            ci: CIState(rawRollup: rollup?.state),
            failedCIChecks: rollup?.contexts?.failedChecks ?? [],
            labels: labels?.nodes.map { PRLabel(name: $0.name, colorHex: $0.color) } ?? [],
            diffStats: PRDiffStats(
                additions: additions ?? 0,
                deletions: deletions ?? 0,
                changedFiles: changedFiles ?? 0
            )
        )
    }
}
