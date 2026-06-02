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
        .frame(width: 380, height: 520)
        .onChange(of: settings.toggleTeams) { _ in onApply() }
        .onChange(of: settings.toggleDirect) { _ in onApply() }
        .onChange(of: settings.toggleMentioned) { _ in onApply() }
    }
}
