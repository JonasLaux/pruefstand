import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let source = try String(contentsOfFile: "Sources/Pruefstand/GHClient.swift", encoding: .utf8)

expect(source.contains("reviewThreads(first: 100)"), "review thread window should stay bounded")
expect(source.contains("comments(first: 1)"), "only one review-thread comment node should be fetched for author attribution")
expect(!source.contains("comments(first: 100)"), "review-thread comment nodes must not blow past GitHub GraphQL node limits")
