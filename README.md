# Pruefstand

A small macOS menu bar app for tracking GitHub pull requests that need your review.

It uses the locally authenticated `gh` CLI, polls for open review requests, shows them in a popover, and can send native notifications for newly surfaced PRs.
The popover has two tabs, **My Pull Requests** (the PRs you authored) and **My Review Needed** (PRs requesting your review); swipe horizontally with two fingers, or click the segmented control, to switch between them. A toolbar above the list filters by repo or tag and changes the sort order (created, updated, repo, or CI state).

Each PR row shows compact review status metadata:

- total comment count, combining issue comments and review-thread comments
- unresolved review-thread count, with a hover tooltip grouped by author
- CI rollup state, with a hover tooltip listing failed check runs/status contexts when CI fails
- labels, diff stats, author, age, repo, and PR number in a single-line row layout

Status hover details use a short-delay cached tooltip panel anchored to the
hovered badge, so CI and unresolved-comment details remain available while the
popover refreshes and are not clipped by the row layout.

## Row actions

Each PR row exposes quick actions. The set depends on the tab:

- **Approve** submits an approval review with `gh pr review --approve` (review tab only).
- **Close** closes the PR without merging with `gh pr close`.
- **Ignore** hides the PR locally by repo and number; it stays hidden until you
  clear it from Settings -> Ignored PRs.
- **Nudge** / **Urgent nudge** run your configured local commands (see
  [Nudge commands](#nudge-commands)). They appear only when a command is set.

Approve and Close prompt for confirmation and drop the PR from the list on
success. Launch with `--debug-actions` to exercise the action UI in dry-run
mode: prompts and progress states render, but no GitHub mutation, local ignore,
or command is performed.

## Getting started

1. Make sure the GitHub CLI is installed and authenticated:

```sh
gh auth status
```

If that fails, run:

```sh
gh auth login
```

2. Build and launch the app:

```sh
swift build
swift run Pruefstand
```

For safe UI testing with mock data, use preview mode:

```sh
swift run Pruefstand --preview
```

3. Open Settings from the menu bar popover and choose which PRs to watch.
   - Under **Which PRs**, set the review scope: **My teams** (includes direct
     requests), **Directly requested to me**, or **Mentioned me**.
   - Use **Watched repos** to scope the list to one or more repositories.
   - Use **Watched contributors** to check one or more active authors, or add a
     login manually, to include PRs even when you are not requested as a reviewer.
   - Toggle **Include drafts** when draft PRs should be shown too.
   - Use **Hidden authors** to suppress PRs from specific logins; bot accounts
     (`renovate`, `dependabot`, `github-actions`, and any `[bot]` login) are
     hidden by default.
   - **Ignored PRs** shows the locally ignored count and a **Clear** button to
     un-hide them all.

4. Optional: configure [Nudge commands](#nudge-commands) so each PR row can run
your own local reminder workflow. For example, this asks Codex to draft a review
nudge and copies it to the clipboard:

```sh
codex "Draft a concise, friendly PR review reminder. PR: $PR_TITLE. Repo: $PR_REPO. Open for $PR_AGE_DAYS days. Link: $PR_URL." | pbcopy
```

Pruefstand only runs the command with PR context. The command decides whether to
copy text, open another app, call a local agent, or hand off to one of your own
scripts.

## Build

```sh
swift build
```

To assemble a local `.app` bundle:

```sh
./scripts/bundle.sh
```

Rebuild the bundle after code changes before reopening `Pruefstand.app`; `swift
build` updates the SwiftPM binary, while the bundle script copies the release
binary into the app bundle.

For UI iteration, launch the app in preview-window mode with mock PR data:

```sh
swift run Pruefstand --preview
```

To test action UI against real PR data without approving or closing anything:

```sh
swift run Pruefstand --debug-actions
```

Or, after bundling:

```sh
open Pruefstand.app --args --preview
```

```sh
open Pruefstand.app --args --debug-actions
```

## Checks

Run the lightweight repository checks before committing:

```sh
./scripts/check-launch-mode.sh
```

The script compiles focused Swift checks for launch/action behavior, settings,
filters, nudge command interpolation, PR status metadata decoding, GraphQL query
budget guardrails, popover layout invariants, and status tooltip interaction
behavior.

## Nudge commands

Pruefstand can run local commands for a PR from the row actions:

- **Nudge** runs the configured default reminder command.
- **Urgent nudge** runs the configured escalation command.

Configure them in Settings -> Commands. Empty commands hide their buttons. Commands
run through `/bin/zsh -lc` with a GUI-safe PATH prefix:

```text
/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
```

Pruefstand does not authenticate Slack, email, or any other delivery channel. The
command decides what happens. For example:

```sh
codex "Draft a concise, friendly PR review reminder. PR: $PR_TITLE. Repo: $PR_REPO. Open for $PR_AGE_DAYS days. Link: $PR_URL." | pbcopy
```

or:

```sh
~/bin/pr-nudge {url}
```

### Environment variables

Every nudge command receives these variables:

| Variable | Description |
| --- | --- |
| `PR_TITLE` | Pull request title |
| `PR_URL` | Browser URL for the pull request |
| `PR_REPO` | Repository name with owner |
| `PR_NUMBER` | Pull request number without `#` |
| `PR_AUTHOR` | GitHub login of the PR author |
| `PR_CREATED_AT` | ISO-8601 creation timestamp |
| `PR_UPDATED_AT` | ISO-8601 update timestamp |
| `PR_AGE_DAYS` | Whole days since creation, minimum `0` |
| `PR_REVIEW_DECISION` | GitHub review decision when available |
| `PR_COMMENT_COUNT` | Total PR issue comment count |
| `PR_CI_STATE` | `success`, `failure`, `pending`, or `none` |
| `PR_ADDITIONS` | Added line count |
| `PR_DELETIONS` | Deleted line count |
| `PR_CHANGED_FILES` | Changed file count |
| `PR_LABELS` | Comma-separated label names |

### Placeholders

Placeholders are replaced before the command is passed to the shell. They are
POSIX shell-quoted, so use them as standalone shell words:

```sh
~/bin/pr-nudge {url}
```

For natural-language prompts, prefer environment variables inside a quoted string:

```sh
codex "Write a review nudge for $PR_TITLE: $PR_URL" | pbcopy
```

| Placeholder | Environment variable |
| --- | --- |
| `{title}` | `PR_TITLE` |
| `{url}` | `PR_URL` |
| `{repo}` | `PR_REPO` |
| `{number}` | `PR_NUMBER` |
| `{author}` | `PR_AUTHOR` |
| `{created_at}` | `PR_CREATED_AT` |
| `{updated_at}` | `PR_UPDATED_AT` |
| `{age_days}` | `PR_AGE_DAYS` |
| `{review_decision}` | `PR_REVIEW_DECISION` |
| `{comment_count}` | `PR_COMMENT_COUNT` |
| `{ci_state}` | `PR_CI_STATE` |
| `{additions}` | `PR_ADDITIONS` |
| `{deletions}` | `PR_DELETIONS` |
| `{changed_files}` | `PR_CHANGED_FILES` |
| `{labels}` | `PR_LABELS` |

Unknown placeholders are left unchanged.

### Prompt an agent

You can ask a local agent to write a command:

```text
Write me a Pruefstand Nudge command.

It can use these variables:
PR_TITLE, PR_URL, PR_REPO, PR_AUTHOR, PR_AGE_DAYS, PR_CHANGED_FILES, PR_LABELS.

I want it to ask Codex to draft a short friendly PR review reminder and copy the
result to my clipboard. Do not hardcode PR-specific values.
```
