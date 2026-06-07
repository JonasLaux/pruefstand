# Pruefstand Nudge Commands - Design

Date: 2026-06-07
Status: Approved

## Purpose

Pruefstand should let the user run local, user-defined "nudge" automations for a
pull request without knowing or authenticating against the final delivery channel.
The app remains local-first: it surfaces PRs through the existing `gh` CLI flow and
executes configured shell commands on demand.

The first two command slots are:

- **Nudge** - the default, polite review reminder.
- **Urgent Nudge** - a stronger escalation for stale or blocking work.

These names describe intent only. Pruefstand does not know Slack, email, Codex,
Claude, Raycast, or any other destination. The user decides what each command does.

## User Experience

Each PR row shows two additional action buttons when their commands are configured:

- `bell` icon for **Nudge**.
- `exclamationmark.bubble` icon for **Urgent Nudge**.

Clicking a nudge action opens the same inline confirmation overlay pattern used by
the existing approve/close actions. Confirming runs the configured command for that
PR. While the command is running, the row shows a progress overlay. On success, the
row shows a short success message. On failure, it shows the command's stderr/stdout
summary.

In preview or debug action mode, command actions do not execute. The UI shows a
dry-run success state so the interaction can be tested safely.

## Settings

Settings adds a **Commands** section with two editable slots:

| Setting | Type | Default |
| --- | --- | --- |
| `nudgeCommand` | String | empty |
| `urgentNudgeCommand` | String | empty |

An empty command disables that row action. The app does not need separate enabled
toggles for v1; "empty means disabled" keeps the model simple and easy to document.

Each command is a shell command string. It runs through `/bin/zsh -lc <command>` so
users can rely on normal shell features, PATH setup, pipelines, redirects, command
substitution, and tools configured in their login shell environment.

## Command Data Contract

When Pruefstand runs a nudge command, it exposes PR context in two ways:

1. Environment variables for scripts and robust shell commands.
2. Template placeholders for simple one-line commands.

Template placeholders are replaced before the command is passed to the shell.
Placeholder values are POSIX shell-quoted, so they are safest when used as standalone
shell words. For natural-language agent prompts, prefer environment variables inside
a quoted prompt string. Environment variables are always set, even when the command
does not use placeholders.

Good placeholder use:

```bash
~/bin/pr-nudge {url}
```

Good environment variable use for an agent prompt:

```bash
codex "Draft a friendly PR review nudge for $PR_TITLE: $PR_URL" | pbcopy
```

Example command that asks an agent to produce the final text:

```bash
codex "Write a concise review nudge for $PR_TITLE in $PR_REPO. URL: $PR_URL. Age: $PR_AGE_DAYS days." | pbcopy
```

## Environment Variables

All values are strings. Missing optional PR values are exposed as empty strings.

| Environment variable | Description | Example |
| --- | --- | --- |
| `PR_TITLE` | Pull request title | `Tighten reviewer assignment flow` |
| `PR_URL` | Browser URL for the pull request | `https://github.com/acme/app/pull/42` |
| `PR_REPO` | Repository name with owner | `acme/app` |
| `PR_NUMBER` | Pull request number without `#` | `42` |
| `PR_AUTHOR` | GitHub login of the PR author | `alice` |
| `PR_CREATED_AT` | ISO-8601 creation timestamp | `2026-06-04T10:15:00Z` |
| `PR_UPDATED_AT` | ISO-8601 update timestamp | `2026-06-06T18:30:00Z` |
| `PR_AGE_DAYS` | Whole days since creation, minimum `0` | `3` |
| `PR_REVIEW_DECISION` | GitHub review decision when available | `REVIEW_REQUIRED` |
| `PR_COMMENT_COUNT` | Total PR issue comment count | `7` |
| `PR_CI_STATE` | Normalized CI state | `success`, `failure`, `pending`, or `none` |
| `PR_ADDITIONS` | Added line count | `428` |
| `PR_DELETIONS` | Deleted line count | `91` |
| `PR_CHANGED_FILES` | Changed file count | `12` |
| `PR_LABELS` | Comma-separated label names | `needs-review,area:app` |

## Template Placeholders

Placeholders are lowercase and wrapped in braces. They map directly to the
environment variable contract.

| Placeholder | Equivalent environment variable |
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

Unknown placeholders are left unchanged. This makes typos visible in command output
instead of silently erasing user input.

## Agent-Writable Commands

The docs should explicitly invite users to ask a local AI agent to write or improve
their command. The agent-facing rules are:

- Use the documented environment variables and placeholders.
- Avoid hardcoding a specific PR title, URL, number, or repository.
- Keep side effects obvious, such as copying to the clipboard, opening an app, or
  writing to a known file.
- Prefer commands that are safe to run repeatedly.
- Exit non-zero when the command fails.
- Keep secrets out of the command string. Use the user's shell environment,
  keychain-backed tools, or already-authenticated CLIs.

Suggested prompt:

```text
Write me a Pruefstand Nudge command.

It can use these environment variables:
PR_TITLE, PR_URL, PR_REPO, PR_AUTHOR, PR_AGE_DAYS, PR_CHANGED_FILES, PR_LABELS.

I want it to ask Codex to draft a short friendly PR review reminder and copy the
result to my clipboard. Do not hardcode any PR-specific values.
```

Example answer:

```bash
codex "Draft a concise, friendly PR review reminder. PR: $PR_TITLE. Repo: $PR_REPO. Author: $PR_AUTHOR. Open for $PR_AGE_DAYS days. Changed files: $PR_CHANGED_FILES. Labels: $PR_LABELS. Link: $PR_URL." | pbcopy
```

## Command Execution

Command execution should be isolated from GitHub-specific code. Add a small command
runner unit that:

- Builds the PR environment dictionary.
- Interpolates placeholders.
- Runs `/bin/zsh -lc <interpolated command>`.
- Adds a GUI-safe PATH prefix: `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`.
- Captures stdout and stderr.
- Enforces a timeout of 120 seconds.
- Returns success, failure, or timeout.

Failure messages should be concise. Prefer stderr when available, then stdout. Trim
whitespace and cap displayed output to a short single-line summary.

Commands should not remove PRs from the list on success. A nudge is a side effect,
not a review completion.

## Error Handling

- Empty command: hide the corresponding action button.
- Non-zero exit: show `Command failed (exit N): <summary>`.
- Timeout: terminate the process and show `Command timed out after 120s`.
- Process launch failure: show the localized launch error.
- Unknown placeholders: leave them unchanged.

## Testing

Focused tests should cover:

- Environment variable generation for a representative `PullRequest`.
- Placeholder interpolation, including spaces, quotes, labels, and unknown
  placeholders.
- Empty commands disabling actions.
- Command result mapping for success, non-zero exit, and timeout where practical.
- Preview/debug action mode dry-runs nudge actions without executing commands.

## Out of Scope

- Built-in Slack, email, or chat API integrations.
- Storing API tokens.
- Scheduling automatic nudges.
- Per-reviewer identity mapping.
- Running commands without confirmation.
- Editing commands per PR from the row.
