import AppKit
import SwiftUI

enum HorizontalSwipeDirection {
    case previous
    case next
}

enum HorizontalSwipeEvent {
    case progress(CGFloat)
    case completed(CGFloat)
}

struct HorizontalSwipeMonitor: NSViewRepresentable {
    let canSwipePrevious: Bool
    let canSwipeNext: Bool
    let onEvent: (HorizontalSwipeEvent) -> Void

    func makeNSView(context: Context) -> HorizontalSwipeMonitorNSView {
        let view = HorizontalSwipeMonitorNSView()
        view.canSwipePrevious = canSwipePrevious
        view.canSwipeNext = canSwipeNext
        view.onEvent = onEvent
        return view
    }

    func updateNSView(_ nsView: HorizontalSwipeMonitorNSView, context: Context) {
        nsView.canSwipePrevious = canSwipePrevious
        nsView.canSwipeNext = canSwipeNext
        nsView.onEvent = onEvent
    }

    static func dismantleNSView(_ nsView: HorizontalSwipeMonitorNSView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class HorizontalSwipeMonitorNSView: NSView {
    var canSwipePrevious = false
    var canSwipeNext = false
    var onEvent: (HorizontalSwipeEvent) -> Void = { _ in }

    private var monitor: Any?
    private var isTrackingSwipe = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func stopMonitoring() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard canSwipePrevious || canSwipeNext else { return false }
        guard let window, let eventWindow = event.window, eventWindow === window else { return false }
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled else { return false }
        guard event.hasPreciseScrollingDeltas else { return false }
        guard event.phase.contains(.began) || event.phase.contains(.changed) else { return false }
        guard !isTrackingSwipe else { return true }

        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return false }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        guard abs(dx) > max(CGFloat(2), abs(dy) * 1.35) else { return false }

        isTrackingSwipe = true
        let minPage = canSwipeNext ? CGFloat(-1) : CGFloat(0)
        let maxPage = canSwipePrevious ? CGFloat(1) : CGFloat(0)
        let options: NSEvent.SwipeTrackingOptions = [.lockDirection, .clampGestureAmount]

        event.trackSwipeEvent(
            options: options,
            dampenAmountThresholdMin: minPage,
            max: maxPage
        ) { [weak self] gestureAmount, _, isComplete, _ in
            guard let self else { return }
            self.emitSwipeEvent(gestureAmount: -gestureAmount, isComplete: isComplete)
        }

        return true
    }

    private func emitSwipeEvent(gestureAmount: CGFloat, isComplete: Bool) {
        let event: HorizontalSwipeEvent = isComplete ? .completed(gestureAmount) : .progress(gestureAmount)
        if Thread.isMainThread {
            onEvent(event)
            if isComplete {
                isTrackingSwipe = false
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onEvent(event)
                if isComplete {
                    self.isTrackingSwipe = false
                }
            }
        }
    }
}
