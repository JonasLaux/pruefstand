import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let labels = [
    PRLabel(name: "complexity:high", colorHex: "d73a4a"),
    PRLabel(name: "complexity:low", colorHex: "0e8a16"),
    PRLabel(name: "area:app", colorHex: "1d76db"),
    PRLabel(name: "bug", colorHex: "d73a4a")
]

let complexityPrefix = TagFilter.prefix("complexity:")
let bugExact = TagFilter.exact("bug")
let missingPrefix = TagFilter.prefix("risk:")

expect(complexityPrefix.matches(labels: labels), "complexity:* should match complexity labels")
expect(bugExact.matches(labels: labels), "exact bug filter should match bug label")
expect(!missingPrefix.matches(labels: labels), "risk:* should not match when no risk labels exist")

let prefixOptions = TagFilter.prefixOptions(from: labels)
expect(prefixOptions.map(\.displayTitle) == ["area:*", "complexity:*"], "prefix options should be sorted and deduped")
expect(TagFilter.matchesAny([complexityPrefix], labels: labels), "selected complexity:* should include PR")
expect(!TagFilter.matchesAny([missingPrefix], labels: labels), "selected risk:* should exclude PR")
