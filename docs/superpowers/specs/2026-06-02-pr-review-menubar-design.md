# Pruefstand Menu Bar App — Design

Date: 2026-06-02
Status: Approved (pending spec review)

## Purpose

A macOS menu bar app that surfaces every open PR the user needs to review, sourced
from the locally-authenticated `gh` CLI. Filterable by repo, author (bot exclusion),
sortable, polled on a configurable interval, with optional native notifications when
a new review-needed PR appears. Notifications can be paused from the menu bar.

Single-user, local, unsigned. No PR actions (approve/merge) from the app.

## Stack & Build

- **Language/UI:** Swift + SwiftUI, AppKit (`NSStatusItem`, `NSPopover`) for menu bar.
- **Build:** SwiftPM executable target. A `scripts/bundle.sh` assembles a `.app`
  bundle from the built binary plus a generated `Info.plist`.
- **Info.plist essentials:** `LSUIElement = true` (no Dock icon), a stable
  `CFBundleIdentifier` (e.g. `com.jonaslaux.pruefstand`) — required so
  `UNUserNotificationCenter` works (notifications need a bundled, identified app).
- **Distribution:** run unsigned locally. No code signing / notarization.
  Optional: register as a Login Item for auto-start (nice-to-have, not required).

## Data Layer

All data comes from the already-authenticated `gh` CLI via a single GraphQL call
per poll (no N+1):

```
gh api graphql -f query='<query>'
```

- **`gh` discovery:** resolve binary via `which gh`; fall back to
  `/opt/homebrew/bin/gh` then `/usr/local/bin/gh`. If not found or not
  authenticated (`gh auth status` fails), show an error state in the popover.
- **Query:** `search(query: <built-from-toggles>, type: ISSUE, first: 50)` returning
  per PR:
  - `number`, `title`, `url`
  - `repository { nameWithOwner }`
  - `author { login, avatarUrl }`
  - `createdAt`, `updatedAt`
  - `reviewDecision`
  - `comments { totalCount }`
  - `reviewThreads(first: 100)` with `isResolved`, `comments { totalCount }`,
    and one comment author node for unresolved-thread attribution
  - `commits(last: 1)` with `statusCheckRollup { state }` plus bounded check
    contexts for failed-CI tooltips
- **GraphQL budget:** nested review-thread comments intentionally fetch
  `comments(first: 1)` rather than every comment node. The row needs total review
  comment counts and one author per unresolved thread, not all review comment
  bodies. This keeps the GitHub query under the possible-node limit.
- **Decoding:** `Codable` models (`PullRequest`, `Repository`, `Author`, `CIState`).

### Search query construction (from Settings toggles)

Three toggles map to GitHub search qualifiers:

| Toggle           | Qualifier                      |
|------------------|--------------------------------|
| Direct request   | `user-review-requested:@me`    |
| My teams         | `review-requested:@me` (superset: direct + team) |
| Mentioned        | `mentions:@me`                 |

Always combined with `is:open is:pr`.

Because qualifiers AND within a single GitHub search, OR-ing across toggles requires
running up to **2 search queries** and merging + deduping by PR id client-side:

- If **My teams** is on, use `review-requested:@me` (it already includes direct, so
  the Direct toggle is implied/disabled-as-redundant in the UI).
- Else if **Direct** is on, use `user-review-requested:@me`.
- If **Mentioned** is on, run an additional `mentions:@me` search and merge results.

Default toggles on first run: **My teams = on** (covers direct + teams), others off.

## Components

Each unit has one purpose, a defined interface, and is independently testable.

- **`GHClient`** — runs `gh api graphql`, returns `[PullRequest]`. Builds the query
  string from toggle settings. Knows nothing about UI. Surfaces a typed error
  (`ghNotFound`, `notAuthenticated`, `decodeFailed`, `processFailed`).
- **`PRStore`** (`ObservableObject`) — single source of truth. Holds the raw fetched
  list; exposes a derived, filtered + sorted list to views. Owns filter/sort state.
- **`Poller`** — drives refresh. A main `Timer` fires every X minutes (from Settings).
  A second short timer (~30s) runs **only while the popover is open** to live-refresh
  CI/check state. Coalesces overlapping refreshes (no concurrent gh calls).
- **`MenuBarController`** — owns `NSStatusItem`; badge shows count of review-needed
  PRs; click toggles the `NSPopover`. Also owns the right-click / status menu:
  Refresh now, Pause/Resume notifications, Settings…, Quit.
- **`NotificationManager`** — wraps `UNUserNotificationCenter`. Maintains a persisted
  `Set<String>` of "seen" PR ids. On each poll, ids that are new **and** need review
  trigger a notification (one per PR, click opens the PR url). Gated by the pause flag.
- **`Settings`** — persisted to `UserDefaults`:
  - `pollIntervalMinutes` (default 5)
  - search toggles: `direct`, `teams`, `mentioned`
  - `repoFilter` (set of selected `nameWithOwner`, empty = all)
  - `authorBlocklist` (default `renovate`, `dependabot`, `github-actions`; plus a
    rule matching any login ending in `[bot]`)
  - `sortKey` (created | updated | repo | ciState)
  - `notificationsEnabled`, `notificationsPaused`
  - `seenPRIds`

## UI — Popover

Rich scrollable list. **Each row:**

- PR title (single line, truncating)
- repo `nameWithOwner` and PR number (single line, secondary text)
- labels (up to three chips)
- author avatar + login
- relative age ("opened 3d ago", from `createdAt`)
- diff stats
- total comment count with icon (`comments.totalCount` + review-thread comment totals)
- unresolved review-thread count with icon; hover shows a grouped author list, for
  example `2 coderabbitai`, `1 codex`
- CI rollup badge: green (success) / red (failure) / yellow (pending) / gray (none) /
  spinner while a live refresh is in flight; hover on failure lists the failed
  check runs/status contexts
- whole row clickable → opens `url` in default browser

The menu-bar popover uses a fixed shared width (`PopoverLayout.width`) so the
SwiftUI view and AppKit panel stay in sync. Row metadata is constrained to
single-line compact groups to avoid overlap or wrapping when comments, unresolved
threads, diff stats, and CI status are all present.

Status hover details use an app-level non-activating tooltip panel instead of
native `.help` or row-local SwiftUI overlays. The panel is anchored from the
hovered badge's screen coordinates with a short reveal delay, which keeps
tooltips responsive during refreshes and prevents row clipping from hiding them.

**Top bar:** repo filter (multi-select menu), tag filter, sort dropdown, manual
refresh button.

**States:** loading (first fetch), empty ("Nothing to review 🎉"), error (gh missing /
not authed, with the resolved cause).

CI badges update live while the popover is open (driven by `Poller`'s short timer).

## Filtering / Sorting

Applied client-side in `PRStore` over the fetched list:

- **Repo filter:** multi-select; options populated from repos observed in current
  results. Empty selection = show all.
- **Author blocklist:** PRs whose `author.login` is in the blocklist (or matches the
  `[bot]` suffix rule) are hidden. Blocklist editable in Settings.
- **Sort:** created (newest first default) / updated / repo (A–Z) / CI state.

## Notifications

- Persisted `seenPRIds` set. Each poll:
  1. Compute current review-needed PR ids.
  2. `new = current − seen` that still need review → if `notificationsEnabled` and not
     `notificationsPaused`, post one notification per new PR.
  3. Update `seen = current` **always** (even when paused), so resuming does not
     flood with a backlog.
- Notification click action opens the PR url.
- **Pause/Resume** is a menu bar toggle: a pure gate on posting. Polling and the
  seen-set update continue while paused.

## Error Handling

- `gh` not found → popover error state with install/auth hint.
- `gh auth status` failure → "Not authenticated, run `gh auth login`".
- GraphQL/network/decode failure → keep last good list, show a transient error banner
  in the top bar; retry on next poll.
- Process timeout (gh hangs) → kill after N seconds, treat as `processFailed`.

## Testing

- `GHClient` query-builder: unit tests mapping toggle combinations → expected query
  strings and number of search calls.
- JSON decoding: fixture GraphQL responses → `PullRequest` models, incl. missing CI,
  missing author, multiple repos.
- PR status metadata decoding: fixture GraphQL response → failed check names,
  total comments, unresolved thread author grouping, and tooltip text.
- GraphQL budget guardrail: source check that nested review-thread comments stay at
  `first: 1` so the query does not exceed GitHub's possible-node limit.
- Popover layout guardrail: source check that the panel/view share width constants
  and row metadata uses compact single-line items.
- `PRStore` filter/sort: given a fixed list, assert repo filter, blocklist (incl.
  `[bot]` suffix), and each sort order.
- `NotificationManager` diff logic: seen-set transitions, paused gating, no-flood on
  resume — tested against the diff function (no real `UNUserNotificationCenter`).

## Out of Scope (YAGNI)

- Approving / merging / commenting on PRs from the app.
- Multiple GitHub accounts.
- Per-PR live websocket/streaming updates.
- Signed / notarized distribution.
