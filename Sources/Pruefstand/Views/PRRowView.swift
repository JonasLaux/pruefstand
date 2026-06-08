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
        HStack(alignment: .top, spacing: 10) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 10) {
                    avatar
                    textStack
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            actionButtons
                .padding(.top, 1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 7)
        .padding(.leading, 10)
        .padding(.trailing, 12)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pr.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .help(pr.title)
            repoLine
            if !pr.labels.isEmpty {
                tagRow
            }
            metadataRow
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        Group {
            if visibleActions.count <= 2 {
                VStack(spacing: 6) {
                    actionButtonList
                }
                .frame(width: 20, alignment: .top)
            } else {
                LazyVGrid(columns: actionButtonColumns, spacing: 6) {
                    actionButtonList
                }
                .frame(width: 46, alignment: .top)
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
        commandActions + [.ignore, .approve, .close]
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
            let message = dryRun ? "Dry-run: would \(action.label.lowercased())" : action.successMessage
            Text(message)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dryRun ? Color.secondary : Color.green)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(message)
        case .failed(_, let message):
            Text(message)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(message)
        case .running, nil:
            EmptyView()
        }
    }

    private var repoLine: some View {
        HStack(spacing: 6) {
            Text(pr.repo)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
                .help(pr.repo)
            Text("#\(pr.number)")
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataRow: some View {
        HStack(alignment: .center, spacing: 8) {
            authorMetadata
            metadataLabel(relativeAge, systemImage: "clock")
            DiffStatsView(stats: pr.diffStats)
            metadataLabel(
                compactCount(pr.commentCount),
                systemImage: "bubble.left",
                help: "\(pr.commentCount) comments"
            )
            ciBadge
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authorMetadata: some View {
        Label {
            Text(pr.authorLogin)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "person")
        }
        .frame(maxWidth: 72, alignment: .leading)
        .help(pr.authorLogin)
    }

    private func metadataLabel(_ title: String, systemImage: String, help: String? = nil) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .help(help ?? title)
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
        case .ignore: return .secondary
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
                let remainingLabels = pr.labels.dropFirst(3).map(\.name).joined(separator: ", ")
                Text("+\(pr.labels.count - 3)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.14), in: Capsule())
                    .help(remainingLabels)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("+\(compactCount(stats.additions))")
                .foregroundStyle(.green)
            Text("-\(compactCount(stats.deletions))")
                .foregroundStyle(.red)
            Label(compactCount(stats.changedFiles), systemImage: "doc.text")
                .labelStyle(.titleAndIcon)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .help("+\(stats.additions) additions, -\(stats.deletions) deletions, \(stats.changedFiles) changed files")
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
            .truncationMode(.tail)
            .frame(maxWidth: 96, alignment: .leading)
            .help(label.name)
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

private func compactCount(_ value: Int) -> String {
    let sign = value < 0 ? "-" : ""
    let magnitude = abs(value)

    if magnitude >= 1_000_000 {
        let whole = magnitude / 1_000_000
        let decimal = (magnitude % 1_000_000) / 100_000
        return decimal == 0 ? "\(sign)\(whole)m" : "\(sign)\(whole).\(decimal)m"
    }

    if magnitude >= 1_000 {
        let whole = magnitude / 1_000
        let decimal = (magnitude % 1_000) / 100
        return decimal == 0 ? "\(sign)\(whole)k" : "\(sign)\(whole).\(decimal)k"
    }

    return "\(value)"
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
