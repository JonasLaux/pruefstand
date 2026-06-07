import Foundation

struct PRLabel: Equatable, Hashable, Identifiable {
    var id: String { name }

    let name: String
    let colorHex: String
}

enum TagFilter: Equatable, Hashable, RawRepresentable {
    case exact(String)
    case prefix(String)

    init?(rawValue: String) {
        if rawValue.hasPrefix("exact:") {
            self = .exact(String(rawValue.dropFirst("exact:".count)))
        } else if rawValue.hasPrefix("prefix:") {
            self = .prefix(String(rawValue.dropFirst("prefix:".count)))
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .exact(let name): return "exact:\(name)"
        case .prefix(let prefix): return "prefix:\(prefix)"
        }
    }

    var displayTitle: String {
        switch self {
        case .exact(let name):
            return name
        case .prefix(let prefix):
            return "\(prefix)*"
        }
    }

    func matches(label: PRLabel) -> Bool {
        switch self {
        case .exact(let name):
            return label.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        case .prefix(let prefix):
            return label.name.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    func matches(labels: [PRLabel]) -> Bool {
        labels.contains { matches(label: $0) }
    }

    static func matchesAny(_ filters: Set<TagFilter>, labels: [PRLabel]) -> Bool {
        filters.isEmpty || filters.contains { $0.matches(labels: labels) }
    }

    static func prefixOptions(from labels: [PRLabel]) -> [TagFilter] {
        let prefixes = labels.compactMap { label -> String? in
            guard let colon = label.name.firstIndex(of: ":") else { return nil }
            return String(label.name[...colon])
        }
        return Set(prefixes)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map(TagFilter.prefix)
    }
}
