import AppKit
import SwiftUI

@MainActor
final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    private let actionMode: PRActionMode
    private let settings: Settings
    private lazy var store = PRStore(settings: settings)
    private var window: NSWindow?

    init(actionMode: PRActionMode) {
        self.actionMode = actionMode
        let defaults = UserDefaults.previewDefaults()
        self.settings = Settings(userDefaults: defaults)
        super.init()
        settings.notificationsEnabled = false
        settings.notificationsPaused = true
        settings.authorBlocklist = []
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.setFetched(PreviewPullRequests.samples(relativeTo: Date()))

        let content = PreviewWindowContent(store: store, settings: settings, actionMode: actionMode)
        let hosting = NSHostingView(rootView: content)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: PopoverLayout.previewWindowWidth, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Pruefstand Preview"
        win.contentView = hosting
        win.center()
        win.makeKeyAndOrderFront(nil)
        window = win

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private extension UserDefaults {
    static func previewDefaults() -> UserDefaults {
        let suiteName = "com.jonaslaux.pruefstand.preview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private enum PreviewTab: Hashable {
    case popover
    case settings
}

private struct PreviewWindowContent: View {
    @ObservedObject var store: PRStore
    @ObservedObject var settings: Settings
    let actionMode: PRActionMode
    @State private var selectedTab = PreviewTab.popover

    var body: some View {
        TabView(selection: $selectedTab) {
            popoverPreview
                .tabItem { Label("Popover", systemImage: "menubar.rectangle") }
                .tag(PreviewTab.popover)

            SettingsView(settings: settings, onApply: {})
                .padding(.vertical, 12)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(PreviewTab.settings)
        }
        .frame(minWidth: 440, minHeight: 560)
    }

    private var popoverPreview: some View {
        VStack {
            PopoverView(
                store: store,
                settings: settings,
                height: 440,
                actionMode: actionMode,
                onRefresh: simulateRefresh,
                onPRAction: simulateAction,
                onOpenSettings: { selectedTab = .settings },
                onQuit: { NSApp.terminate(nil) }
            )
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(radius: 12, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func simulateRefresh() {
        guard !store.isLoading else { return }
        store.isLoading = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                store.setFetched(PreviewPullRequests.samples(relativeTo: Date()))
                store.isLoading = false
            }
        }
    }

    private func simulateAction(_ action: PRAction, _ pr: PullRequest) {
        if case .running = store.actionStatuses[pr.id] { return }
        store.beginAction(action, for: pr)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                store.finishAction(action, for: pr, dryRun: true)
            }
        }
    }
}

private enum PreviewPullRequests {
    static func samples(relativeTo now: Date) -> PRFetchResult {
        PRFetchResult(
            myPullRequests: myPullRequestSamples(relativeTo: now),
            reviewNeeded: reviewNeededSamples(relativeTo: now)
        )
    }

    private static func myPullRequestSamples(relativeTo now: Date) -> [PullRequest] {
        [
            sample(
                number: 241,
                title: "Add review-needed tabs and horizontal trackpad switching",
                repo: "jonaslaux/pruefstand",
                author: "jonaslaux",
                createdAt: now.addingTimeInterval(-54 * 60),
                updatedAt: now.addingTimeInterval(-11 * 60),
                comments: 5,
                reviewComments: 2,
                unresolvedReviewThreadsByAuthor: [
                    ReviewThreadAuthorCount(author: "mira", count: 1)
                ],
                ci: .success,
                diffStats: PRDiffStats(additions: 156, deletions: 29, changedFiles: 4),
                labels: [
                    PRLabel(name: "area:popover", colorHex: "1d76db"),
                    PRLabel(name: "ui", colorHex: "5319e7")
                ]
            ),
            sample(
                number: 382,
                title: "Split notification state from preview-window launch state",
                repo: "tools/review-surface",
                author: "jonaslaux",
                createdAt: now.addingTimeInterval(-19 * 60 * 60),
                updatedAt: now.addingTimeInterval(-2 * 60 * 60),
                comments: 1,
                ci: .pending,
                diffStats: PRDiffStats(additions: 83, deletions: 16, changedFiles: 3),
                labels: [
                    PRLabel(name: "complexity:low", colorHex: "0e8a16")
                ]
            ),
            sample(
                number: 114,
                title: "Tidy command interpolation docs for local review nudges",
                repo: "example/desktop-shell",
                author: "jonaslaux",
                createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                updatedAt: now.addingTimeInterval(-6 * 60 * 60),
                comments: 8,
                ci: .failure,
                failedCIChecks: [
                    FailedCICheck(name: "Docs smoke test")
                ],
                diffStats: PRDiffStats(additions: 37, deletions: 11, changedFiles: 2),
                labels: [
                    PRLabel(name: "docs", colorHex: "0075ca")
                ]
            )
        ]
    }

    private static func reviewNeededSamples(relativeTo now: Date) -> [PullRequest] {
        [
            sample(
                number: 482,
                title: "Tighten reviewer assignment flow for repository teams with long names",
                repo: "jonaslaux/pruefstand",
                author: "mira",
                createdAt: now.addingTimeInterval(-38 * 60),
                updatedAt: now.addingTimeInterval(-8 * 60),
                comments: 4,
                reviewComments: 7,
                unresolvedReviewThreadsByAuthor: [
                    ReviewThreadAuthorCount(author: "coderabbitai", count: 2),
                    ReviewThreadAuthorCount(author: "codex", count: 1)
                ],
                ci: .failure,
                failedCIChecks: [
                    FailedCICheck(name: "Unit tests"),
                    FailedCICheck(name: "deploy preview")
                ],
                diffStats: PRDiffStats(additions: 428, deletions: 91, changedFiles: 12),
                labels: [
                    PRLabel(name: "complexity:high", colorHex: "d73a4a"),
                    PRLabel(name: "area:app", colorHex: "1d76db"),
                    PRLabel(name: "needs-review", colorHex: "fbca04")
                ]
            ),
            sample(
                number: 1298,
                title: "Add cached avatar loading and compact row spacing",
                repo: "example/desktop-shell",
                author: "andrei",
                createdAt: now.addingTimeInterval(-3 * 60 * 60),
                updatedAt: now.addingTimeInterval(-24 * 60),
                comments: 12,
                ci: .pending,
                diffStats: PRDiffStats(additions: 118, deletions: 36, changedFiles: 7),
                labels: [
                    PRLabel(name: "complexity:medium", colorHex: "fbca04"),
                    PRLabel(name: "ui", colorHex: "5319e7")
                ]
            ),
            sample(
                number: 77,
                title: "Refresh menu bar count after applying repo filters",
                repo: "tools/review-surface",
                author: "sana",
                createdAt: now.addingTimeInterval(-26 * 60 * 60),
                updatedAt: now.addingTimeInterval(-2 * 60 * 60),
                comments: 1,
                ci: .success,
                diffStats: PRDiffStats(additions: 24, deletions: 8, changedFiles: 2),
                labels: [
                    PRLabel(name: "complexity:low", colorHex: "0e8a16"),
                    PRLabel(name: "bug", colorHex: "d73a4a")
                ]
            ),
            sample(
                number: 921,
                title: "Investigate flaky notification delivery on cold launch",
                repo: "infra/macos-agents",
                author: "lee",
                createdAt: now.addingTimeInterval(-4 * 24 * 60 * 60),
                updatedAt: now.addingTimeInterval(-7 * 60 * 60),
                comments: 0,
                ci: .none,
                diffStats: PRDiffStats(additions: 63, deletions: 117, changedFiles: 5),
                labels: [
                    PRLabel(name: "area:notifications", colorHex: "0052cc"),
                    PRLabel(name: "risk:flaky", colorHex: "b60205")
                ]
            )
        ]
    }

    private static func sample(
        number: Int,
        title: String,
        repo: String,
        author: String,
        createdAt: Date,
        updatedAt: Date,
        comments: Int,
        reviewComments: Int = 0,
        unresolvedReviewThreadsByAuthor: [ReviewThreadAuthorCount] = [],
        ci: CIState,
        failedCIChecks: [FailedCICheck] = [],
        diffStats: PRDiffStats,
        labels: [PRLabel]
    ) -> PullRequest {
        PullRequest(
            id: "https://github.com/\(repo)/pull/\(number)",
            number: number,
            title: title,
            url: "https://github.com/\(repo)/pull/\(number)",
            repo: repo,
            authorLogin: author,
            authorAvatarURL: nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reviewDecision: "REVIEW_REQUIRED",
            commentCount: comments,
            reviewCommentCount: reviewComments,
            unresolvedReviewThreadsByAuthor: unresolvedReviewThreadsByAuthor,
            ci: ci,
            failedCIChecks: failedCIChecks,
            labels: labels,
            diffStats: diffStats
        )
    }
}
