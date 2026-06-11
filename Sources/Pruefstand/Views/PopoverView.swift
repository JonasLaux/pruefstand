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
    @State private var selectedTab: PullRequestTab = .reviewNeeded
    @State private var transitionDirection: HorizontalSwipeDirection = .next
    @State private var swipeProgress: CGFloat = 0
    @State private var isSwipeTracking = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: PopoverLayout.width, height: height)
        .background {
            HorizontalSwipeMonitor(
                canSwipePrevious: tab(before: selectedTab) != nil,
                canSwipeNext: tab(after: selectedTab) != nil,
                onEvent: handleSwipeEvent
            )
        }
    }

    private var topBar: some View {
        VStack(spacing: 7) {
            tabPicker

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
        }
        .padding(8)
    }

    private var tabPicker: some View {
        Picker("Pull request list", selection: tabSelection) {
            ForEach(PullRequestTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private var tagFilterMenu: some View {
        Menu {
            Button("All tags") { settings.tagFilters = [] }
            if !currentAvailableTagPrefixes.isEmpty {
                Divider()
                Section("Prefixes") {
                    ForEach(currentAvailableTagPrefixes, id: \.self) { filter in
                        tagFilterButton(filter)
                    }
                }
            }
            if !currentAvailableLabels.isEmpty {
                Divider()
                Section("Tags") {
                    ForEach(currentAvailableLabels) { label in
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
            ForEach(store.availableRepos(for: selectedTab), id: \.self) { repo in
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
        GeometryReader { proxy in
            ZStack {
                if isSwipeTracking {
                    swipePageStack(width: proxy.size.width)
                } else {
                    page(for: selectedTab)
                        .id(selectedTab)
                        .transition(tabTransition)
                }
            }
            .clipped()
        }
    }

    @ViewBuilder
    private func swipePageStack(width: CGFloat) -> some View {
        let offset = -swipeProgress * width

        ZStack {
            if let previous = tab(before: selectedTab) {
                page(for: previous)
                    .offset(x: -width + offset)
            }
            page(for: selectedTab)
                .offset(x: offset)
            if let next = tab(after: selectedTab) {
                page(for: next)
                    .offset(x: width + offset)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func page(for tab: PullRequestTab) -> some View {
        if let err = store.lastError {
            errorState(err)
        } else if pullRequests(for: tab).isEmpty {
            emptyState(for: tab)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pullRequests(for: tab)) { pr in
                        PRRowView(
                            pr: pr,
                            actionStatus: store.actionStatuses[pr.id],
                            actionMode: actionMode,
                            actions: actions(for: tab),
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

    private func emptyState(for tab: PullRequestTab) -> some View {
        VStack(spacing: 8) {
            Text(tab.emptyTitle)
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

    private var tabSelection: Binding<PullRequestTab> {
        Binding(
            get: { selectedTab },
            set: { selectTab($0, animated: true) }
        )
    }

    private var tabTransition: AnyTransition {
        switch transitionDirection {
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        }
    }

    private var currentAvailableTagPrefixes: [TagFilter] {
        store.availableTagPrefixes(for: selectedTab)
    }

    private var currentAvailableLabels: [PRLabel] {
        store.availableLabels(for: selectedTab)
    }

    private func actions(for tab: PullRequestTab) -> [PRAction] {
        switch tab {
        case .myPullRequests:
            return settings.availableCommandActions + [.ignore, .close]
        case .reviewNeeded:
            return settings.availableCommandActions + [.ignore, .approve, .close]
        }
    }

    private func pullRequests(for tab: PullRequestTab) -> [PullRequest] {
        store.displayed(for: tab)
    }

    private func selectTab(_ tab: PullRequestTab, animated: Bool) {
        guard selectedTab != tab else { return }
        transitionDirection = direction(from: selectedTab, to: tab)

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedTab = tab
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                selectedTab = tab
            }
        }
    }

    private func handleSwipeEvent(_ event: HorizontalSwipeEvent) {
        switch event {
        case .progress(let amount):
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                isSwipeTracking = true
                swipeProgress = amount
            }
        case .completed(let amount):
            let target = targetTab(forCompletedGestureAmount: amount)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                if let target {
                    transitionDirection = direction(from: selectedTab, to: target)
                    selectedTab = target
                }
                swipeProgress = 0
                isSwipeTracking = false
            }
        }
    }

    private func targetTab(forCompletedGestureAmount amount: CGFloat) -> PullRequestTab? {
        if amount <= -0.5 {
            return tab(before: selectedTab)
        }
        if amount >= 0.5 {
            return tab(after: selectedTab)
        }
        return nil
    }

    private func direction(from oldTab: PullRequestTab, to newTab: PullRequestTab) -> HorizontalSwipeDirection {
        let tabs = PullRequestTab.allCases
        guard
            let oldIndex = tabs.firstIndex(of: oldTab),
            let newIndex = tabs.firstIndex(of: newTab)
        else {
            return .next
        }
        return newIndex > oldIndex ? .next : .previous
    }

    private func tab(before tab: PullRequestTab) -> PullRequestTab? {
        let tabs = PullRequestTab.allCases
        guard let index = tabs.firstIndex(of: tab), index > tabs.startIndex else {
            return nil
        }
        return tabs[tabs.index(before: index)]
    }

    private func tab(after tab: PullRequestTab) -> PullRequestTab? {
        let tabs = PullRequestTab.allCases
        guard let index = tabs.firstIndex(of: tab), index < tabs.index(before: tabs.endIndex) else {
            return nil
        }
        return tabs[tabs.index(after: index)]
    }
}
