import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let defaultOptions = LaunchOptions.parse(["Pruefstand"])
expect(defaultOptions.mode == .menuBar, "default launch should use menu bar mode")
expect(defaultOptions.actionMode == .live, "default launch should use live actions")

let debugOptions = LaunchOptions.parse(["Pruefstand", "--debug-actions"])
expect(debugOptions.mode == .menuBar, "debug actions should still use menu bar mode")
expect(debugOptions.actionMode == .dryRun, "debug actions should dry-run mutations")

let previewOptions = LaunchOptions.parse(["Pruefstand", "--preview"])
expect(previewOptions.mode == .preview, "preview should use preview mode")
expect(previewOptions.actionMode == .dryRun, "preview should dry-run mutations")

expect(PRAction.approve.ghArguments(for: "https://github.com/example/repo/pull/12") == [
    "pr", "review", "https://github.com/example/repo/pull/12", "--approve"
], "approve command arguments")

expect(PRAction.close.ghArguments(for: "https://github.com/example/repo/pull/12") == [
    "pr", "close", "https://github.com/example/repo/pull/12"
], "close command arguments")

expect(PRAction.approve.isGitHubMutation, "approve should be a GitHub mutation")
expect(PRAction.close.isGitHubMutation, "close should be a GitHub mutation")
expect(!PRAction.nudge.isGitHubMutation, "nudge should be a local command")
expect(!PRAction.urgentNudge.isGitHubMutation, "urgent nudge should be a local command")
expect(!PRAction.ignore.isGitHubMutation, "ignore should be a local settings action")

expect(PRAction.approve.removesPRFromListOnSuccess, "approve should remove reviewed PRs")
expect(PRAction.close.removesPRFromListOnSuccess, "close should remove closed PRs")
expect(!PRAction.nudge.removesPRFromListOnSuccess, "nudge should keep PRs visible")
expect(!PRAction.urgentNudge.removesPRFromListOnSuccess, "urgent nudge should keep PRs visible")
expect(!PRAction.ignore.removesPRFromListOnSuccess, "ignore should rely on filtering raw results")

expect(PRAction.ignore.systemImage == "eye.slash", "ignore icon")
expect(PRAction.nudge.systemImage == "bell", "nudge icon")
expect(PRAction.urgentNudge.systemImage == "exclamationmark.bubble", "urgent nudge icon")
expect(PRAction.ignore.dryRunDetail == "Debug mode: no local ignore will be saved.", "ignore dry-run copy")
expect(PRAction.nudge.dryRunDetail == "Debug mode: no command will be run.", "nudge dry-run copy")
