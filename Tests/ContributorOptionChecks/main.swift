import Foundation
import Dispatch

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

@MainActor
func makePR(
    repo: String,
    number: Int,
    author: String,
    updatedAt: Date,
    commitCount: Int
) -> PullRequest {
    PullRequest(
        id: "https://github.com/\(repo)/pull/\(number)",
        number: number,
        title: "PR \(number)",
        url: "https://github.com/\(repo)/pull/\(number)",
        repo: repo,
        authorLogin: author,
        authorAvatarURL: nil,
        createdAt: updatedAt.addingTimeInterval(-3600),
        updatedAt: updatedAt,
        reviewDecision: nil,
        commentCount: 0,
        ci: .none,
        labels: [],
        diffStats: PRDiffStats(additions: 1, deletions: 0, changedFiles: 1),
        commitCount: commitCount
    )
}

@MainActor
func runChecks() {
    let suiteName = "com.jonaslaux.pruefstand.contributor-option-checks"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let settings = Settings(userDefaults: defaults)
    let store = PRStore(settings: settings)
    settings.addRepoFilter("acme/app")
    settings.addWatchedContributor("zoe")

    store.setFetched(
        PRFetchResult(
            myPullRequests: [],
            reviewNeeded: [
                makePR(repo: "acme/app", number: 1, author: "alice", updatedAt: Date(timeIntervalSince1970: 300), commitCount: 2),
                makePR(repo: "acme/app", number: 2, author: "bob", updatedAt: Date(timeIntervalSince1970: 200), commitCount: 7),
                makePR(repo: "acme/app", number: 3, author: "Alice", updatedAt: Date(timeIntervalSince1970: 100), commitCount: 5),
                makePR(repo: "acme/api", number: 4, author: "charlie", updatedAt: Date(timeIntervalSince1970: 400), commitCount: 50)
            ],
            contributorCandidates: [
                RepositoryContributor(repo: "acme/app", login: "alice", contributions: 120),
                RepositoryContributor(repo: "acme/app", login: "bob", contributions: 95)
            ]
        )
    )

    let options = store.contributorOptions
    expect(options.map(\.login) == ["alice", "bob", "zoe"], "contributors should be repo-scoped, deduped, selected-preserving, and activity sorted")
    expect(options[0].pullRequestCount == 2, "alice should aggregate PR count case-insensitively")
    expect(options[0].commitCount == 120, "alice should use repository contribution count")
    expect(options[0].isSelected == false, "alice should not be selected")
    expect(options[2].isSelected, "selected contributor with no loaded PRs should stay visible")
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
