import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: PRStore
    @ObservedObject var settings: Settings
    let height: CGFloat
    let actionMode: PRActionMode
    let onRefresh: () -> Void
    let onPRAction: (PRAction, PullRequest) -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: PopoverLayout.width, height: height)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            repoFilterMenu
            tagFilterMenu
            sortMenu
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
        .padding(8)
    }

    private var tagFilterMenu: some View {
        Menu {
            Button("All tags") { settings.tagFilters = [] }
            if !store.availableTagPrefixes.isEmpty {
                Divider()
                Section("Prefixes") {
                    ForEach(store.availableTagPrefixes, id: \.self) { filter in
                        tagFilterButton(filter)
                    }
                }
            }
            if !store.availableLabels.isEmpty {
                Divider()
                Section("Tags") {
                    ForEach(store.availableLabels) { label in
                        tagFilterButton(.exact(label.name))
                    }
                }
            }
        } label: {
            Label(tagFilterLabel, systemImage: "tag")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func tagFilterButton(_ filter: TagFilter) -> some View {
        Button {
            if settings.tagFilters.contains(filter) {
                settings.tagFilters.remove(filter)
            } else {
                settings.tagFilters.insert(filter)
            }
        } label: {
            Label(filter.displayTitle, systemImage: settings.tagFilters.contains(filter) ? "checkmark" : "")
        }
    }

    private var tagFilterLabel: String {
        if settings.tagFilters.isEmpty { return "Tags" }
        if settings.tagFilters.count == 1 { return "1 tag" }
        return "\(settings.tagFilters.count) tags"
    }

    private var repoFilterMenu: some View {
        Menu {
            Button("All repos") { settings.repoFilter = [] }
            Divider()
            ForEach(store.availableRepos, id: \.self) { repo in
                Button {
                    if settings.repoFilter.contains(repo) {
                        settings.repoFilter.remove(repo)
                    } else {
                        settings.repoFilter.insert(repo)
                    }
                } label: {
                    Label(repo, systemImage: settings.repoFilter.contains(repo) ? "checkmark" : "")
                }
            }
        } label: {
            Label(repoFilterLabel, systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var repoFilterLabel: String {
        if settings.repoFilter.isEmpty { return "All repos" }
        if settings.repoFilter.count == 1 { return settings.repoFilter.first! }
        return "\(settings.repoFilter.count) repos"
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortKey.allCases, id: \.self) { key in
                Button {
                    settings.sortKey = key
                } label: {
                    Label(key.label, systemImage: settings.sortKey == key ? "checkmark" : "")
                }
            }
        } label: {
            Label("Sort: \(settings.sortKey.label)", systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        if let err = store.lastError {
            errorState(err)
        } else if store.displayed.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.displayed) { pr in
                        PRRowView(
                            pr: pr,
                            actionStatus: store.actionStatuses[pr.id],
                            actionMode: actionMode,
                            commandActions: settings.availableCommandActions,
                            onAction: onPRAction
                        )
                        Divider()
                    }
                }
            }
        }
    }

    private func errorState(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(err)
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing to review")
                .font(.headline)
            Text("🎉")
                .font(.largeTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button {
                settings.notificationsPaused.toggle()
            } label: {
                Label(
                    settings.notificationsPaused ? "Notifications paused" : "Notifications on",
                    systemImage: settings.notificationsPaused ? "bell.slash" : "bell"
                )
            }
            .buttonStyle(.borderless)
            if actionMode == .dryRun {
                Label("Dry-run", systemImage: "hammer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            Button(action: onQuit) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
        .padding(8)
    }
}
