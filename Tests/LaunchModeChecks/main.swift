import Foundation

func expect(_ actual: LaunchMode, _ expected: LaunchMode, _ message: String) {
    guard actual == expected else {
        fatalError("\(message): expected \(expected), got \(actual)")
    }
}

expect(LaunchMode.parse(["Pruefstand"]), .menuBar, "Default launch mode")
expect(LaunchMode.parse(["Pruefstand", "--preview"]), .preview, "Preview flag launch mode")
