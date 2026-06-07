import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let formatter = ISO8601DateFormatter()
let created = formatter.date(from: "2026-06-04T10:15:00Z")!
let updated = formatter.date(from: "2026-06-06T18:30:00Z")!
let now = formatter.date(from: "2026-06-07T12:00:00Z")!

let pr = PullRequest(
    id: "https://github.com/acme/app/pull/42",
    number: 42,
    title: "Tighten \"review\" flow",
    url: "https://github.com/acme/app/pull/42",
    repo: "acme/app",
    authorLogin: "alice",
    authorAvatarURL: nil,
    createdAt: created,
    updatedAt: updated,
    reviewDecision: "REVIEW_REQUIRED",
    commentCount: 7,
    ci: .success,
    labels: [
        PRLabel(name: "needs-review", colorHex: "fbca04"),
        PRLabel(name: "area:app", colorHex: "1d76db")
    ],
    diffStats: PRDiffStats(additions: 428, deletions: 91, changedFiles: 12)
)

let env = PRCommandContext.environment(for: pr, now: now)
expect(env["PR_TITLE"] == "Tighten \"review\" flow", "title env")
expect(env["PR_URL"] == "https://github.com/acme/app/pull/42", "url env")
expect(env["PR_REPO"] == "acme/app", "repo env")
expect(env["PR_NUMBER"] == "42", "number env")
expect(env["PR_AUTHOR"] == "alice", "author env")
expect(env["PR_CREATED_AT"] == "2026-06-04T10:15:00Z", "created env")
expect(env["PR_UPDATED_AT"] == "2026-06-06T18:30:00Z", "updated env")
expect(env["PR_AGE_DAYS"] == "3", "age env")
expect(env["PR_REVIEW_DECISION"] == "REVIEW_REQUIRED", "review decision env")
expect(env["PR_COMMENT_COUNT"] == "7", "comment count env")
expect(env["PR_CI_STATE"] == "success", "ci env")
expect(env["PR_ADDITIONS"] == "428", "additions env")
expect(env["PR_DELETIONS"] == "91", "deletions env")
expect(env["PR_CHANGED_FILES"] == "12", "changed files env")
expect(env["PR_LABELS"] == "needs-review,area:app", "labels env")

let rendered = PRCommandContext.interpolate("run {url} {unknown} {title}", environment: env)
expect(
    rendered == "run 'https://github.com/acme/app/pull/42' {unknown} 'Tighten \"review\" flow'",
    "placeholder interpolation"
)
expect(PRCommandContext.shellQuote("can't stop") == "'can'\"'\"'t stop'", "single quote escaping")
expect(PRCommandContext.shellQuote("") == "''", "empty shell quote")
