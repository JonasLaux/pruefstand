import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let onApply: () -> Void

    @State private var newBlockEntry = ""

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
                if settings.toggleTeams {
                    Text("Teams already covers direct requests.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Toggle("Enabled", isOn: $settings.notificationsEnabled)
                Toggle("Paused", isOn: $settings.notificationsPaused)
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
        .frame(width: 420, height: 660)
        .onChange(of: settings.toggleTeams) { _ in onApply() }
        .onChange(of: settings.toggleDirect) { _ in onApply() }
        .onChange(of: settings.toggleMentioned) { _ in onApply() }
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
}
