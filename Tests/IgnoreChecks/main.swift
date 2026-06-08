import Foundation
import Dispatch

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

@MainActor
func makePR(repo: String, number: Int, title: String) -> PullRequest {
    PullRequest(
        id: "https://github.com/\(repo)/pull/\(number)",
        number: number,
        title: title,
        url: "https://github.com/\(repo)/pull/\(number)",
        repo: repo,
        authorLogin: "octocat",
        authorAvatarURL: nil,
        createdAt: Date(timeIntervalSince1970: TimeInterval(number)),
        updatedAt: Date(timeIntervalSince1970: TimeInterval(number + 100)),
        reviewDecision: nil,
        commentCount: 0,
        ci: .none,
        labels: [],
        diffStats: PRDiffStats(additions: 1, deletions: 0, changedFiles: 1)
    )
}

@MainActor
func runChecks() {
    let suiteName = "com.jonaslaux.pruefstand.ignore-checks"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let firstSettings = Settings(userDefaults: defaults)
    let firstStore = PRStore(settings: firstSettings)
    let ignored = makePR(repo: "acme/app", number: 42, title: "Ignored PR")
    let visibleSameNumber = makePR(repo: "acme/api", number: 42, title: "Visible PR")

    firstStore.setRaw([ignored, visibleSameNumber])
    firstSettings.ignore(pr: ignored)

    expect(firstStore.raw.count == 2, "ignore should not mutate raw results")
    expect(firstStore.displayed == [visibleSameNumber], "ignored PR should be hidden by repo and number")

    let secondSettings = Settings(userDefaults: defaults)
    let secondStore = PRStore(settings: secondSettings)
    secondStore.setRaw([ignored, visibleSameNumber])

    expect(secondStore.displayed == [visibleSameNumber], "ignored PR should persist across settings reloads")
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
