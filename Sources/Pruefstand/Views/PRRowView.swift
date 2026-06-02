import SwiftUI

struct PRRowView: View {
    let pr: PullRequest

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 10) {
                avatar
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
                    HStack(spacing: 10) {
                        Label(pr.authorLogin, systemImage: "person")
                        Label(relativeAge, systemImage: "clock")
                        Label("\(pr.commentCount)", systemImage: "bubble.left")
                        ciBadge
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
