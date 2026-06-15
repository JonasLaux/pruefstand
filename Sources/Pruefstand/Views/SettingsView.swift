import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: PRStore
    @ObservedObject var settings: Settings
    let onApply: () -> Void

    @State private var newBlockEntry = ""
    @State private var newRepoEntry = ""
    @State private var newContributorEntry = ""

    var body: some View {
        Form {
            Section("Polling") {
                Stepper(value: $settings.pollIntervalMinutes, in: 1...120) {
                    Text("Every \(settings.pollIntervalMinutes) min")
                }
            }

            Section("Which PRs") {
                Toggle("My teams (includes direct requests)", isOn: $settings.toggleTeams)
                Toggle("Directly requested to me", isOn: $settings.toggleDirect)
                    .disabled(settings.toggleTeams)
                Toggle("Mentioned me", isOn: $settings.toggleMentioned)
                Toggle("Include drafts", isOn: $settings.includeDrafts)
                if settings.toggleTeams {
                    Text("Teams already covers direct requests.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Watched repos") {
                ForEach(Array(settings.repoFilter).sorted(), id: \.self) { repo in
                    HStack {
                        Text(repo)
                        Spacer()
                        Button {
                            settings.removeRepoFilter(repo)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("owner/repo or GitHub URL", text: $newRepoEntry)
                    Button("Add") {
                        settings.addRepoFilter(newRepoEntry)
                        newRepoEntry = ""
                    }
                }
                Text("Empty means all accessible repositories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Watched contributors") {
                if store.contributorOptions.isEmpty {
                    Text("No contributors found")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.contributorOptions) { option in
                                Toggle(isOn: contributorBinding(option.login)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.login)
                                        Text(option.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 180)
                }
                HStack {
                    TextField("add GitHub login", text: $newContributorEntry)
                    Button("Add") {
                        settings.addWatchedContributor(newContributorEntry)
                        newContributorEntry = ""
                    }
                }
                Text("Fetched even when you are not requested as a reviewer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Enabled", isOn: $settings.notificationsEnabled)
                Toggle("Paused", isOn: $settings.notificationsPaused)
            }

            Section("Ignored PRs") {
                HStack {
                    Text("\(settings.ignoredPRKeys.count) ignored")
                    Spacer()
                    Button("Clear") {
                        settings.clearIgnoredPRs()
                    }
                    .disabled(settings.ignoredPRKeys.isEmpty)
                }
                Text("Ignored PRs are stored locally by repo and number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Commands") {
                commandEditor("Nudge", text: $settings.nudgeCommand)
                commandEditor("Urgent nudge", text: $settings.urgentNudgeCommand)
            }

            Section("Hidden authors") {
                ForEach(settings.authorBlocklist, id: \.self) { author in
                    HStack {
                        Text(author)
                        Spacer()
                        Button {
                            settings.authorBlocklist.removeAll { $0 == author }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("add login", text: $newBlockEntry)
                    Button("Add") {
                        let trimmed = newBlockEntry.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !settings.authorBlocklist.contains(trimmed) else { return }
                        settings.authorBlocklist.append(trimmed)
                        newBlockEntry = ""
                    }
                }
                Text("Logins ending in [bot] are always hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 760)
        .onChange(of: settings.toggleTeams) { _ in onApply() }
        .onChange(of: settings.toggleDirect) { _ in onApply() }
        .onChange(of: settings.toggleMentioned) { _ in onApply() }
        .onChange(of: settings.includeDrafts) { _ in onApply() }
        .onChange(of: settings.repoFilter) { _ in onApply() }
        .onChange(of: settings.watchedContributors) { _ in onApply() }
    }

    private func commandEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 62)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 0.8)
                }
        }
        .padding(.vertical, 2)
    }

    private func contributorBinding(_ login: String) -> Binding<Bool> {
        Binding(
            get: {
                settings.watchedContributors.contains {
                    $0.caseInsensitiveCompare(login) == .orderedSame
                }
            },
            set: { selected in
                if selected {
                    settings.addWatchedContributor(login)
                } else {
                    settings.removeWatchedContributor(login)
                }
            }
        )
    }
}
