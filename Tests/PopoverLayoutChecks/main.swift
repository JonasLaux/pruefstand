import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let layoutSource = try String(contentsOfFile: "Sources/Pruefstand/PopoverLayout.swift", encoding: .utf8)
let rowSource = try String(contentsOfFile: "Sources/Pruefstand/Views/PRRowView.swift", encoding: .utf8)
let controllerSource = try String(contentsOfFile: "Sources/Pruefstand/MenuBarController.swift", encoding: .utf8)
let popoverSource = try String(contentsOfFile: "Sources/Pruefstand/Views/PopoverView.swift", encoding: .utf8)

expect(layoutSource.contains("static let width: CGFloat = 580"), "popover should use the wider fixed width")
expect(controllerSource.contains("PopoverLayout.width"), "menu bar panel should share the popover width")
expect(popoverSource.contains("PopoverLayout.width"), "SwiftUI popover should share the popover width")
expect(rowSource.contains(".lineLimit(1)"), "row text should explicitly avoid wrapping")
expect(rowSource.contains("private var metadataRow"), "PR row should use a dedicated metadata row")
expect(rowSource.contains("MetaItem("), "metadata should use compact fixed single-line items")
