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
let modelSource = try String(contentsOfFile: "Sources/Pruefstand/Models.swift", encoding: .utf8)
let swipeSource = try String(contentsOfFile: "Sources/Pruefstand/Views/HorizontalSwipeMonitor.swift", encoding: .utf8)

expect(layoutSource.contains("static let width: CGFloat = 580"), "popover should use the wider fixed width")
expect(controllerSource.contains("PopoverLayout.width"), "menu bar panel should share the popover width")
expect(popoverSource.contains("PopoverLayout.width"), "SwiftUI popover should share the popover width")
expect(modelSource.contains("return \"My Pull Requests\""), "popover tab should include My Pull Requests")
expect(modelSource.contains("return \"My Review Needed\""), "popover tab should include My Review Needed")
expect(popoverSource.contains("Picker(\"Pull request list\""), "popover should render tabs as a segmented picker")
expect(popoverSource.contains(".frame(maxWidth: .infinity)"), "popover tabs should use the full available width")
expect(popoverSource.contains("HorizontalSwipeMonitor("), "popover should observe horizontal trackpad swipe gestures")
expect(popoverSource.contains("swipePageStack(width:"), "popover should render a sliding page stack for trackpad swipes")
expect(popoverSource.contains("transition(tabTransition)"), "segmented tab changes should use a directional slide transition")
expect(swipeSource.contains("NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)"), "trackpad swipe should monitor scrollWheel events")
expect(swipeSource.contains("trackSwipeEvent("), "trackpad swipe should use AppKit fluid swipe tracking")
expect(swipeSource.contains("dampenAmountThresholdMin: minPage"), "trackpad swipe should dampen unavailable directions")
expect(controllerSource.contains("displayed(for: .reviewNeeded)"), "menu bar badge should count review-needed PRs")
expect(rowSource.contains(".lineLimit(1)"), "row text should explicitly avoid wrapping")
expect(rowSource.contains("private var metadataRow"), "PR row should use a dedicated metadata row")
expect(rowSource.contains("MetaItem("), "metadata should use compact fixed single-line items")
