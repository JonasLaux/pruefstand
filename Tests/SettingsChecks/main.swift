import Foundation
import Dispatch

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

@MainActor
func runChecks() {
    let suiteName = "com.jonaslaux.pruefstand.settings-checks"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let settings = Settings(userDefaults: defaults)
    expect(settings.command(for: .nudge) == nil, "empty nudge command should be disabled")
    expect(settings.command(for: .urgentNudge) == nil, "empty urgent nudge command should be disabled")
    expect(settings.availableCommandActions.isEmpty, "no empty command actions should be visible")
    expect(settings.includeDrafts == false, "draft PRs should be excluded by default")
    expect(settings.watchedContributors.isEmpty, "watched contributors should default empty")

    settings.nudgeCommand = "codex \"Draft for $PR_TITLE\""
    expect(settings.command(for: .nudge) == "codex \"Draft for $PR_TITLE\"", "nudge command should trim and return")
    expect(settings.availableCommandActions == [.nudge], "nudge action should be visible")

    settings.urgentNudgeCommand = "  ~/bin/urgent {url}  "
    expect(settings.command(for: .urgentNudge) == "~/bin/urgent {url}", "urgent command should trim")
    expect(settings.availableCommandActions == [.nudge, .urgentNudge], "configured actions should keep display order")

    settings.includeDrafts = true
    settings.addWatchedContributor(" @Alice ")
    settings.addWatchedContributor("alice")
    settings.addWatchedContributor("BOB")
    expect(settings.watchedContributors == ["alice", "bob"], "watched contributors should normalize and dedupe")

    settings.addRepoFilter("https://github.com/bobsled-inc/bobsled-ai/pull/42")
    settings.addRepoFilter(" bobsled-inc/bobsled-nl-sql ")
    expect(
        settings.repoFilter == ["bobsled-inc/bobsled-ai", "bobsled-inc/bobsled-nl-sql"],
        "repo entries should normalize GitHub URLs and owner/name input"
    )

    let reloaded = Settings(userDefaults: defaults)
    expect(reloaded.includeDrafts, "include drafts should persist")
    expect(reloaded.watchedContributors == ["alice", "bob"], "watched contributors should persist")
    expect(
        reloaded.repoFilter == ["bobsled-inc/bobsled-ai", "bobsled-inc/bobsled-nl-sql"],
        "repo filter should persist"
    )
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
