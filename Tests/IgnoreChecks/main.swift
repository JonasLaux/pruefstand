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
    let authored = makePR(repo: "acme/app", number: 43, title: "Authored PR")

    firstStore.setRaw([ignored, visibleSameNumber])
    firstStore.setRaw([ignored, authored], for: .myPullRequests)
    firstSettings.ignore(pr: ignored)

    expect(firstStore.raw.count == 2, "ignore should not mutate raw results")
    expect(firstStore.displayed == [visibleSameNumber], "ignored PR should be hidden by repo and number")
    expect(firstStore.displayed(for: .myPullRequests) == [authored], "ignored PR should be hidden in the authored tab")

    let secondSettings = Settings(userDefaults: defaults)
    let secondStore = PRStore(settings: secondSettings)
    secondStore.setRaw([ignored, visibleSameNumber])
    secondStore.setRaw([ignored, authored], for: .myPullRequests)

    expect(secondStore.displayed == [visibleSameNumber], "ignored PR should persist across settings reloads")
    expect(secondStore.displayed(for: .myPullRequests) == [authored], "ignored PR should persist in the authored tab")
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
