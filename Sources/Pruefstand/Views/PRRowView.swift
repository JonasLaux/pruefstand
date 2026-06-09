import AppKit
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
        .padding(.trailing, 14)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pr.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            HStack(spacing: 6) {
                Text(pr.repo)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("#\(pr.number)")
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
            .font(.system(size: 11))
            .lineLimit(1)
            if !pr.labels.isEmpty {
                tagRow
            }
            metadataRow
            statusLine
        }
    }

    private var metadataRow: some View {
        HStack(alignment: .center, spacing: 8) {
            MetaItem(systemImage: "person", text: pr.authorLogin, maxWidth: 76)
            MetaItem(systemImage: "clock", text: relativeAge, maxWidth: 48)
            DiffStatsView(stats: pr.diffStats)
            commentBadges
            ciBadge
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .lineLimit(1)
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
            .frame(width: 12, height: 12)
            .foregroundStyle(Color(pr.ci.color))
            .cachedTooltip(pr.ciTooltip)
    }

    private var commentBadges: some View {
        HStack(spacing: 7) {
            IconNumberBadge(
                systemImage: "bubble.left",
                value: pr.totalCommentCount,
                color: .secondary,
                help: "Comments: \(pr.totalCommentCount)"
            )
            IconNumberBadge(
                systemImage: "exclamationmark.bubble",
                value: pr.unresolvedReviewThreadCount,
                color: pr.unresolvedReviewThreadCount > 0 ? .orange : .secondary,
                help: pr.unresolvedReviewThreadsTooltip
            )
        }
        .fixedSize(horizontal: true, vertical: false)
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
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MetaItem: View {
    let systemImage: String
    let text: String
    let maxWidth: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .frame(width: 11)
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct IconNumberBadge: View {
    let systemImage: String
    let value: Int
    let color: Color
    let help: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .frame(width: 12)
            Text("\(value)")
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .cachedTooltip(help)
    }
}

private struct CachedHoverTooltip: ViewModifier {
    let text: String
    private let tooltipWidth: CGFloat = 220
    @State private var isHovering = false
    @State private var isPresented = false
    @State private var revealTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay {
                TooltipAnchorView(text: text, width: tooltipWidth, isPresented: isPresented)
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                isHovering = hovering
                revealTask?.cancel()
                if hovering {
                    revealTask = Task {
                        try? await Task.sleep(for: .milliseconds(90))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            if isHovering {
                                isPresented = true
                            }
                        }
                    }
                } else {
                    isPresented = false
                }
            }
            .onDisappear {
                revealTask?.cancel()
                isHovering = false
                isPresented = false
            }
    }
}

private struct TooltipAnchorView: NSViewRepresentable {
    let text: String
    let width: CGFloat
    let isPresented: Bool

    func makeNSView(context: Context) -> TooltipAnchorNSView {
        TooltipAnchorNSView()
    }

    func updateNSView(_ nsView: TooltipAnchorNSView, context: Context) {
        if isPresented {
            TooltipPanelPresenter.shared.show(text: text, width: width, anchoredTo: nsView)
        } else {
            TooltipPanelPresenter.shared.hide(anchor: nsView)
        }
    }

    static func dismantleNSView(_ nsView: TooltipAnchorNSView, coordinator: ()) {
        TooltipPanelPresenter.shared.hide(anchor: nsView)
    }
}

private final class TooltipAnchorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            TooltipPanelPresenter.shared.hide(anchor: self)
        }
    }
}

@MainActor
private final class TooltipPanelPresenter {
    static let shared = TooltipPanelPresenter()

    private let horizontalInset: CGFloat = 8
    private let verticalGap: CGFloat = 6
    private var panel: NSPanel?
    private var hostingController: NSHostingController<TooltipBubble>?
    private weak var currentAnchor: NSView?

    private init() {}

    func show(text: String, width: CGFloat, anchoredTo anchor: NSView) {
        guard anchor.window != nil else { return }

        currentAnchor = anchor
        let hostingController = hostingController(for: text, width: width)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let panelSize = NSSize(width: max(width, fittingSize.width), height: fittingSize.height)
        hostingController.view.frame = NSRect(origin: .zero, size: panelSize)

        let panel = panel(for: hostingController.view)
        panel.setFrame(frame(for: panelSize, anchoredTo: anchor), display: true)
        panel.orderFrontRegardless()
    }

    func hide(anchor: NSView) {
        guard currentAnchor === anchor else { return }
        hide()
    }

    private func hide() {
        panel?.orderOut(nil)
        currentAnchor = nil
    }

    private func hostingController(for text: String, width: CGFloat) -> NSHostingController<TooltipBubble> {
        let bubble = TooltipBubble(text: text, width: width)
        if let hostingController {
            hostingController.rootView = bubble
            return hostingController
        }

        let hostingController = NSHostingController(rootView: bubble)
        hostingController.view.wantsLayer = true
        self.hostingController = hostingController
        return hostingController
    }

    private func panel(for contentView: NSView) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = contentView
        self.panel = panel
        return panel
    }

    private func frame(for size: NSSize, anchoredTo anchor: NSView) -> NSRect {
        guard let anchorWindow = anchor.window else {
            return NSRect(origin: .zero, size: size)
        }

        let anchorRectInWindow = anchor.convert(anchor.bounds, to: nil)
        let anchorRect = anchorWindow.convertToScreen(anchorRectInWindow)
        let visibleFrame = anchorWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let maxX = visibleFrame.maxX - size.width - horizontalInset
        let minX = visibleFrame.minX + horizontalInset
        let x = max(minX, min(anchorRect.minX - horizontalInset, maxX))

        let preferredY = anchorRect.maxY + verticalGap
        let maxY = visibleFrame.maxY - size.height - verticalGap
        let minY = visibleFrame.minY + verticalGap
        let y = max(minY, min(preferredY, maxY))

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

private struct TooltipBubble: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(8)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.secondary.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)
    }
}

private extension View {
    func cachedTooltip(_ text: String) -> some View {
        modifier(CachedHoverTooltip(text: text))
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
