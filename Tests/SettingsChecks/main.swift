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

    settings.nudgeCommand = "codex \"Draft for $PR_TITLE\""
    expect(settings.command(for: .nudge) == "codex \"Draft for $PR_TITLE\"", "nudge command should trim and return")
    expect(settings.availableCommandActions == [.nudge], "nudge action should be visible")

    settings.urgentNudgeCommand = "  ~/bin/urgent {url}  "
    expect(settings.command(for: .urgentNudge) == "~/bin/urgent {url}", "urgent command should trim")
    expect(settings.availableCommandActions == [.nudge, .urgentNudge], "configured actions should keep display order")
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
