import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    let actionStatus: PRActionStatus?
    let actionMode: PRActionMode
    let commandActions: [PRAction]
    let onAction: (PRAction, PullRequest) -> Void

    @State private var pendingAction: PRAction?

    var body: some View {
        ZStack {
            rowContent
                .opacity(shouldDim ? 0.32 : 1)
                .blur(radius: shouldDim ? 2 : 0)
                .disabled(isRunning)

            if let action = pendingAction {
                confirmationOverlay(for: action)
            } else if case .running(let action) = actionStatus {
                workingOverlay(for: action)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: pendingAction)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 10) {
                    avatar
                    textStack
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            actionButtons
                .padding(.top, 1)
        }
        .padding(.vertical, 6)
        .padding(.leading, 10)
        .padding(.trailing, 30)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pr.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(pr.repo)
                    .foregroundStyle(.secondary)
                Text("#\(pr.number)")
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
            if !pr.labels.isEmpty {
                tagRow
            }
            HStack(alignment: .top, spacing: 10) {
                Label(pr.authorLogin, systemImage: "person")
                Label(relativeAge, systemImage: "clock")
                DiffStatsView(stats: pr.diffStats)
                Label("\(pr.commentCount)", systemImage: "bubble.left")
                ciBadge
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            statusLine
        }
    }

    private var actionButtons: some View {
        Group {
            if visibleActions.count <= 2 {
                VStack(spacing: 6) {
                    actionButtonList
                }
                .frame(width: 20)
            } else {
                LazyVGrid(columns: actionButtonColumns, spacing: 6) {
                    actionButtonList
                }
                .frame(width: 46)
            }
        }
    }

    @ViewBuilder
    private var actionButtonList: some View {
        ForEach(visibleActions, id: \.self) { action in
            RoundActionButton(
                systemImage: action.systemImage,
                color: actionTint(for: action),
                help: action.label
            ) {
                pendingAction = action
            }
        }
    }

    private var visibleActions: [PRAction] {
        commandActions + [.approve, .close]
    }

    private var actionButtonColumns: [GridItem] {
        [
            GridItem(.fixed(20), spacing: 6),
            GridItem(.fixed(20), spacing: 6)
        ]
    }

    @ViewBuilder
    private var statusLine: some View {
        switch actionStatus {
        case .succeeded(let action, let dryRun):
            Text(dryRun ? "Dry-run: would \(action.label.lowercased())" : action.successMessage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dryRun ? Color.secondary : Color.green)
        case .failed(_, let message):
            Text(message)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
        case .running, nil:
            EmptyView()
        }
    }

    private func confirmationOverlay(for action: PRAction) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.promptTitle)
                    .font(.system(size: 13, weight: .semibold))
                Text(actionMode == .dryRun ? action.dryRunDetail : action.promptDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            RoundActionButton(systemImage: "checkmark", color: actionTint(for: action), help: "Confirm") {
                pendingAction = nil
                onAction(action, pr)
            }
            RoundActionButton(systemImage: "xmark", color: .secondary, help: "Cancel") {
                pendingAction = nil
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                actionTint(for: action).opacity(0.20)
                Rectangle().fill(.ultraThinMaterial)
                actionTint(for: action).opacity(0.12)
            }
        }
    }

    private func workingOverlay(for action: PRAction) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(action.progressMessage)
                .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                actionTint(for: action).opacity(0.20)
                Rectangle().fill(.ultraThinMaterial)
                actionTint(for: action).opacity(0.12)
            }
        }
    }

    private func actionTint(for action: PRAction) -> Color {
        switch action {
        case .approve: return .green
        case .close: return .red
        case .nudge: return .blue
        case .urgentNudge: return .orange
        }
    }

    private var shouldDim: Bool {
        pendingAction != nil || isRunning
    }

    private var isRunning: Bool {
        if case .running = actionStatus {
            return true
        }
        return false
    }

    private var tagRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(pr.labels.prefix(3))) { label in
                TagChip(label: label)
            }
            if pr.labels.count > 3 {
                Text("+\(pr.labels.count - 3)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.14), in: Capsule())
            }
        }
        .lineLimit(1)
    }

    private var avatar: some View {
        Group {
            if let s = pr.authorAvatarURL, let url = URL(string: s) {
                AsyncImage(url: url) { img in
                    img.resizable()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var ciBadge: some View {
        Image(systemName: pr.ci.symbolName)
            .foregroundStyle(Color(pr.ci.color))
    }

    private var relativeAge: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: pr.createdAt, relativeTo: Date())
    }

    private func open() {
        if let url = URL(string: pr.url) {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct DiffStatsView: View {
    let stats: PRDiffStats

    var body: some View {
        HStack(spacing: 4) {
            Text("+\(stats.additions)")
                .foregroundStyle(.green)
            Text("-\(stats.deletions)")
                .foregroundStyle(.red)
            Label("\(stats.changedFiles)", systemImage: "doc.text")
                .labelStyle(.titleAndIcon)
        }
    }
}

private struct RoundActionButton: View {
    let systemImage: String
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 20)
                .background(color.opacity(0.18), in: Circle())
                .overlay {
                    Circle().stroke(color.opacity(0.42), lineWidth: 0.8)
                }
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct TagChip: View {
    let label: PRLabel

    var body: some View {
        Text(label.name)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(chipColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.16), in: Capsule())
            .overlay {
                Capsule().stroke(chipColor.opacity(0.28), lineWidth: 0.6)
            }
    }

    private var chipColor: Color {
        guard let color = NSColor(githubHex: label.colorHex) else {
            return Color.secondary
        }
        return Color(nsColor: color)
    }
}

private extension NSColor {
    convenience init?(githubHex: String) {
        let cleaned = githubHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
