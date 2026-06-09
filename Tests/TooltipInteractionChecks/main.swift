import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let rowSource = try String(contentsOfFile: "Sources/Pruefstand/Views/PRRowView.swift", encoding: .utf8)

expect(rowSource.contains("CachedHoverTooltip"), "status tooltips should use an in-popover cached hover surface")
expect(rowSource.contains(".onHover"), "cached hover tooltip should respond to pointer hover")
expect(rowSource.contains("Task.sleep(for: .milliseconds(90))"), "cached hover tooltip should use a short reveal delay")
expect(rowSource.contains("cachedTooltip("), "CI and comment badges should attach cached tooltip content")
expect(rowSource.contains("private let tooltipWidth: CGFloat = 220"), "cached tooltip should have a readable explicit width")
expect(rowSource.contains("TooltipAnchorView"), "cached tooltip should use a stable anchor view")
expect(rowSource.contains("TooltipPanelPresenter"), "cached tooltip should render outside clipped row containers")
expect(rowSource.contains("NSPanel"), "cached tooltip should use a lightweight panel instead of clipped SwiftUI row drawing")
expect(rowSource.contains("convertToScreen"), "cached tooltip should position from the hovered badge's screen coordinates")
expect(rowSource.contains("anchorRect.maxY + verticalGap"), "cached tooltip should prefer north placement above the badge")
expect(rowSource.contains("private let verticalGap: CGFloat = 6"), "cached tooltip should sit tightly above the hovered badge")
expect(rowSource.contains("NSWindow.Level.statusBar.rawValue + 1"), "cached tooltip should render above the menu bar popover panel")
expect(rowSource.contains("ignoresMouseEvents = true"), "cached tooltip should not steal hover from the badge")
expect(rowSource.contains(".frame(width: width"), "cached tooltip must not inherit the badge's tiny proposed width")
expect(!rowSource.contains(".overlay(alignment: .bottomLeading)"), "cached tooltip should not be clipped by row-aligned overlay drawing")
expect(!rowSource.contains(".alignmentGuide(.top)"), "cached tooltip should not rely on fragile alignment-guide placement")
expect(!rowSource.contains(".offset(x: -8, y: -72)"), "cached tooltip should not disappear above clipped row bounds")
expect(!rowSource.contains("y: 24"), "cached tooltip should not offset below the cursor")
expect(!rowSource.contains(".help(pr.ciTooltip)"), "CI tooltip should not rely on native help delay")
expect(!rowSource.contains(".help(pr.unresolvedReviewThreadsTooltip)"), "unresolved tooltip should not rely on native help delay")
