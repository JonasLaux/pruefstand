# PR Nudge Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable local Nudge and Urgent Nudge commands for each PR row, with documented environment variables and placeholders.

**Architecture:** Keep GitHub mutations and user-defined commands separate. Add a Foundation-only command contract/runner for PR command data, extend `PRAction` with nudge cases, wire settings and row buttons through existing action status overlays, and document the user/agent-facing command contract in the README and spec.

**Tech Stack:** Swift 5.9, SwiftUI/AppKit, `Process`, existing Swift script checks in `scripts/check-launch-mode.sh`.

---

## File Structure

- Create `Sources/Pruefstand/PRCommand.swift`: PR environment generation, placeholder interpolation, shell quoting, command execution result, and zsh runner.
- Create `Tests/NudgeCommandChecks/main.swift`: Foundation-level checks for environment variables and interpolation.
- Modify `scripts/check-launch-mode.sh`: compile and run the new command checks.
- Modify `Sources/Pruefstand/PRActions.swift`: add `.nudge` and `.urgentNudge` metadata and flags.
- Modify `Sources/Pruefstand/Settings.swift`: persist `nudgeCommand` and `urgentNudgeCommand`.
- Modify `Sources/Pruefstand/AppDelegate.swift`: route nudge actions to the command runner without removing PRs on success.
- Modify `Sources/Pruefstand/Views/PopoverView.swift` and `Sources/Pruefstand/Views/PRRowView.swift`: pass configured actions and render buttons.
- Modify `Sources/Pruefstand/Views/SettingsView.swift`: expose command editors.
- Modify `README.md`: document command setup, env vars, placeholders, and agent prompts.

## Tasks

### Task 1: Command Contract Tests

**Files:**
- Create: `Tests/NudgeCommandChecks/main.swift`
- Modify: `scripts/check-launch-mode.sh`

- [ ] Add a failing check that constructs a `PullRequest`, calls `PRCommandContext.environment(for:now:)`, and asserts all documented variables.

```swift
let env = PRCommandContext.environment(for: pr, now: now)
expect(env["PR_TITLE"] == "Tighten \"review\" flow", "title env")
expect(env["PR_URL"] == "https://github.com/acme/app/pull/42", "url env")
expect(env["PR_REPO"] == "acme/app", "repo env")
expect(env["PR_NUMBER"] == "42", "number env")
expect(env["PR_AUTHOR"] == "alice", "author env")
expect(env["PR_AGE_DAYS"] == "3", "age env")
expect(env["PR_LABELS"] == "needs-review,area:app", "labels env")
```

- [ ] Add placeholder checks for shell quoting and unknown placeholders.

```swift
let rendered = PRCommandContext.interpolate("run {url} {unknown} {title}", environment: env)
expect(rendered == "run 'https://github.com/acme/app/pull/42' {unknown} 'Tighten \"review\" flow'", "placeholder interpolation")
expect(PRCommandContext.shellQuote("can't stop") == "'can'\"'\"'t stop'", "single quote escaping")
```

- [ ] Update `scripts/check-launch-mode.sh` to compile `Models.swift`, `Labels.swift`, `PRCommand.swift`, and the new check.

```bash
swiftc \
    Sources/Pruefstand/Models.swift \
    Sources/Pruefstand/Labels.swift \
    Sources/Pruefstand/PRCommand.swift \
    Tests/NudgeCommandChecks/main.swift \
    -o .build/nudge-command-check
```

- [ ] Run `./scripts/check-launch-mode.sh`.

Expected before implementation: compile failure because `PRCommand.swift` / `PRCommandContext` does not exist.

### Task 2: Command Contract Implementation

**Files:**
- Create: `Sources/Pruefstand/PRCommand.swift`

- [ ] Implement `PRCommandContext.environment(for:now:)`, `interpolate(_:environment:)`, and `shellQuote(_:)`.

```swift
enum PRCommandContext {
    static func environment(for pr: PullRequest, now: Date = Date()) -> [String: String]
    static func interpolate(_ command: String, environment: [String: String]) -> String
    static func shellQuote(_ value: String) -> String
}
```

- [ ] Run `./scripts/check-launch-mode.sh`.

Expected after implementation: the new command contract check passes.

### Task 3: Settings And Action Model

**Files:**
- Modify: `Sources/Pruefstand/PRActions.swift`
- Modify: `Sources/Pruefstand/Settings.swift`
- Modify: `Tests/ActionModeChecks/main.swift`

- [ ] Add `PRAction.nudge` and `PRAction.urgentNudge`.

```swift
enum PRAction: Equatable, Hashable {
    case approve
    case close
    case nudge
    case urgentNudge
}
```

- [ ] Add metadata: labels, prompt copy, success/progress messages, system icons, `isGitHubMutation`, and `removesPRFromListOnSuccess`.

```swift
var isGitHubMutation: Bool {
    self == .approve || self == .close
}

var removesPRFromListOnSuccess: Bool {
    self == .approve || self == .close
}
```

- [ ] Add persisted `Settings.nudgeCommand` and `Settings.urgentNudgeCommand`.

```swift
@Published var nudgeCommand: String { didSet { d.set(nudgeCommand, forKey: "nudgeCommand") } }
@Published var urgentNudgeCommand: String { didSet { d.set(urgentNudgeCommand, forKey: "urgentNudgeCommand") } }
```

- [ ] Add `Settings.command(for:) -> String?` for command actions.

```swift
func command(for action: PRAction) -> String? {
    switch action {
    case .nudge: return nudgeCommand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    case .urgentNudge: return urgentNudgeCommand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    case .approve, .close: return nil
    }
}
```

### Task 4: Runner And App Delegate Routing

**Files:**
- Modify: `Sources/Pruefstand/PRCommand.swift`
- Modify: `Sources/Pruefstand/AppDelegate.swift`

- [ ] Add `PRCommandRunner` that executes `/bin/zsh -lc <interpolated command>` with the PR environment and a GUI-safe PATH.

```swift
actor PRCommandRunner {
    func run(command: String, for pr: PullRequest, timeoutSeconds: TimeInterval = 120) async throws
}
```

- [ ] Route command actions in `AppDelegate.perform(_:on:)`.

```swift
if action.isGitHubMutation {
    try await client.perform(action: action, onURL: pr.url)
} else if let command {
    try await commandRunner.run(command: command, for: pr)
}
```

- [ ] Keep PRs in the list after successful command actions.

```swift
if actionMode == .live, action.removesPRFromListOnSuccess {
    store.remove(id: pr.id)
}
```

### Task 5: UI Wiring

**Files:**
- Modify: `Sources/Pruefstand/Views/PopoverView.swift`
- Modify: `Sources/Pruefstand/Views/PRRowView.swift`
- Modify: `Sources/Pruefstand/Views/SettingsView.swift`

- [ ] Pass configured command actions into each row.

```swift
PRRowView(
    pr: pr,
    actionStatus: store.actionStatuses[pr.id],
    actionMode: actionMode,
    commandActions: settings.availableCommandActions,
    onAction: onPRAction
)
```

- [ ] Render row buttons from `commandActions + [.approve, .close]`.

```swift
ForEach(actionButtons, id: \.self) { action in
    RoundActionButton(systemImage: action.systemImage, color: actionTint(for: action), help: action.label) {
        pendingAction = action
    }
}
```

- [ ] Add command editors to Settings.

```swift
Section("Commands") {
    commandEditor("Nudge", text: $settings.nudgeCommand)
    commandEditor("Urgent nudge", text: $settings.urgentNudgeCommand)
}
```

### Task 6: Documentation And Verification

**Files:**
- Modify: `README.md`

- [ ] Add a `Nudge commands` section with setup examples, all env vars, all placeholders, and an agent-writing prompt.
- [ ] Run `./scripts/check-launch-mode.sh`.
- [ ] Run `swift build`.
- [ ] Launch preview with `swift run Pruefstand --preview` if build succeeds and inspect the command settings/actions manually.

