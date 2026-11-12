//
//  IceBarInteractionValidation.swift
//  Ice
//

#if SWIFT_PACKAGE
import SwiftUI

/// Runs before normal setup: no status items, preference observers or synthetic input are installed.
@MainActor
enum IceBarInteractionValidation {
    private struct Failure: Error {
        let message: String
    }

    private final class Pause {
        private var continuation: CheckedContinuation<Void, Never>?
        var isWaiting: Bool { continuation != nil }

        func wait() async {
            await withCheckedContinuation { continuation = $0 }
        }

        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(message: message) }
    }

    private static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() {
            try require(ContinuousClock.now < deadline, "Validation did not reach its suspension point")
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    static func run(to directory: URL) -> Never {
        _ = NSApplication.shared
        Task {
            do {
                let state = AppState()
                try validateScreenGeometry()
                try await validateModifiers(state.itemManager)
                try await validateOperations(state.itemManager)
                try await validatePanel(state, to: directory)
                print("PASS: Ice Bar close/reopen/cancel, stable screen anchors, modifier waits and exclusive item operations")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Ice Bar validation failed: \(error)\n".utf8))
                exit(1)
            }
        }
        Task {
            try await Task.sleep(for: .seconds(20))
            FileHandle.standardError.write(Data("Ice Bar validation timed out\n".utf8))
            exit(1)
        }
        while true {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    private static func validateScreenGeometry() throws {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let right = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let above = CGRect(x: 0, y: 982, width: 1512, height: 982)
        let left = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let cases: [(String, CGPoint, [CGRect], Int?)] = [
            ("logged top-edge click", CGPoint(x: 960.5859375, y: 982), [main], 0),
            ("second logged top-edge click", CGPoint(x: 871.6796875, y: 982), [main], 0),
            ("logged interior click", CGPoint(x: 940.76953125, y: 965.01953125), [main], 0),
            ("below top edge", CGPoint(x: 960, y: 981), [main], 0),
            ("above outer edge", CGPoint(x: 960, y: 982.01), [main], nil),
            ("outer top-right corner", CGPoint(x: 1512, y: 982), [main], 0),
            ("outside right edge", CGPoint(x: 1512.01, y: 982), [main], nil),
            ("outside left edge", CGPoint(x: -0.01, y: 982), [main], nil),
            ("horizontal seam", CGPoint(x: 1512, y: 982), [main, right], 1),
            ("horizontal seam reversed", CGPoint(x: 1512, y: 982), [right, main], 0),
            ("external top edge", CGPoint(x: 2400, y: 1080), [main, right], 1),
            ("vertical seam", CGPoint(x: 960, y: 982), [main, above], 0),
            ("vertical seam reversed", CGPoint(x: 960, y: 982), [above, main], 1),
            ("above vertical seam", CGPoint(x: 960, y: 982.01), [main, above], 1),
            ("negative display origin", CGPoint(x: -960, y: 880), [main, left], 1),
            ("outside all displays", CGPoint(x: -960, y: 880.01), [main, left], nil),
        ]
        for (name, point, frames, expected) in cases {
            try require(MenuBarScreenGeometry.screenIndex(at: point, frames: frames) == expected, "Incorrect screen ownership: \(name)")
        }
        print("PASS: logged coordinates, exact screen edges, horizontal/vertical seams, negative origins and outside points")
    }

    private static func validateModifiers(_ manager: MenuBarItemManager) async throws {
        try await manager.waitForNoModifiersPressed(timeout: .milliseconds(30)) {
            [.capsLock, .numericPad, .function, .help]
        }
        for flag: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            do {
                try await manager.waitForNoModifiersPressed(timeout: .milliseconds(30)) { flag }
                throw Failure(message: "An active modifier was accepted")
            } catch is TaskTimeoutError { }
        }
        var flags: NSEvent.ModifierFlags = .shift
        let released = Task { try await manager.waitForNoModifiersPressed { flags } }
        try await Task.sleep(for: .milliseconds(20))
        flags = .capsLock
        try await released.value

        let cancelled = Task { try await manager.waitForNoModifiersPressed { .command } }
        try await Task.sleep(for: .milliseconds(20))
        cancelled.cancel()
        do {
            try await cancelled.value
            throw Failure(message: "A cancelled modifier wait completed successfully")
        } catch is CancellationError { }
        let cancelledWaiter = Task { try await manager.waitForItemsToStopMoving(timeout: .seconds(1)) }
        cancelledWaiter.cancel()
        do {
            try await cancelledWaiter.value
            throw Failure(message: "The nested waiter lost parent cancellation")
        } catch is CancellationError { }
        print("PASS: Caps Lock/device flags ignored; held modifiers time out, release resumes and cancellation finishes")
    }

    private static func validateOperations(_ manager: MenuBarItemManager) async throws {
        var active = 0
        var completed = 0
        let operations = (0..<4).map { _ in
            Task {
                try await manager.withItemOperation {
                    active += 1
                    defer { active -= 1 }
                    try require(active == 1, "Cursor operations overlapped")
                    try await Task.sleep(for: .milliseconds(20))
                    completed += 1
                }
            }
        }
        for operation in operations { try await operation.value }
        try require(completed == 4, "An operation was lost")

        let pause = Pause()
        let owner = Task { try await manager.withItemOperation { await pause.wait() } }
        defer { pause.resume() }
        try await waitUntil { pause.isWaiting }
        var ranCancelledOperation = false
        let cancelled = Task {
            try await manager.withItemOperation { ranCancelledOperation = true }
        }
        try await Task.sleep(for: .milliseconds(20))
        cancelled.cancel()
        do {
            try await cancelled.value
            throw Failure(message: "A cancelled queued operation ran")
        } catch is CancellationError { }
        try require(!ranCancelledOperation, "Cancellation still generated input")
        do {
            try await manager.withItemOperation { throw Failure(message: "A busy owner was bypassed") }
            throw Failure(message: "A busy operation did not time out")
        } catch is TaskTimeoutError { }
        pause.resume()
        try await owner.value
        do {
            try await manager.withItemOperation { throw CancellationError() }
        } catch is CancellationError { }
        try await manager.withItemOperation { completed += 1 }
        try require(completed == 5, "An operation failure leaked ownership")

        var started = false
        let cancelledOwner = Task {
            try await manager.withItemOperation {
                started = true
                try await Task.sleep(for: .seconds(5))
            }
        }
        try await waitUntil { started }
        cancelledOwner.cancel()
        do {
            try await cancelledOwner.value
            throw Failure(message: "The operation owner ignored cancellation")
        } catch is CancellationError { }
        try await manager.withItemOperation { completed += 1 }
        try require(completed == 6, "Cancelling the owner leaked ownership")
        print("PASS: operations serialize, queued work expires/cancels, failure releases ownership")
    }

    private static func validatePanel(_ state: AppState, to directory: URL) async throws {
        guard let screen = NSScreen.main else { throw Failure(message: "No screen") }
        let placement = IceBarPanel.Placement(screen: screen, centerX: screen.frame.midX)
        let panel = state.menuBarManager.iceBarPanel
        panel.isReleasedWhenClosed = false
        panel.performSetup()
        defer { panel.close() }

        let closing = Pause()
        let oldShow = Task { await panel.show(section: .hidden, placement: placement) { await closing.wait() } }
        try await waitUntil { closing.isWaiting }
        try require(panel.currentSection == .hidden, "Pending presentation is not tracked")
        panel.close()
        closing.resume()
        await oldShow.value
        try require(!panel.isVisible && panel.contentView == nil && panel.currentSection == nil, "Closed presentation reopened after delayed loading")
        try require(!state.navigationState.isIceBarPresented, "Closed presentation left navigation state visible")

        let replacing = Pause()
        let replaced = Task { await panel.show(section: .hidden, placement: placement) { await replacing.wait() } }
        try await waitUntil { replacing.isWaiting }
        await panel.show(section: .alwaysHidden, placement: placement) { }
        let currentContent = panel.contentView
        replacing.resume()
        await replaced.value
        try require(panel.isVisible && panel.currentSection == .alwaysHidden && panel.contentView === currentContent, "Stale loading replaced the current presentation")
        panel.close()

        let cancelling = Pause()
        let cancelled = Task { await panel.show(section: .hidden, placement: placement) { await cancelling.wait() } }
        try await waitUntil { cancelling.isWaiting }
        cancelled.cancel()
        cancelling.resume()
        await cancelled.value
        try require(!panel.isVisible && panel.currentSection == nil, "Cancelled loading showed a panel")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var frames = [[String: Any]]()
        for target in NSScreen.screens {
            for location in IceBarLocation.allCases {
                state.settingsManager.generalSettingsManager.iceBarLocation = location
                for clickX in [target.frame.midX, target.frame.maxX - 2] {
                    for clickY in [target.frame.maxY - 1, target.frame.maxY] {
                        let clickPoint = CGPoint(x: clickX, y: clickY)
                        guard let captured = panel.capturePlacement(at: clickPoint, inEmptyMenuBarSpace: true) else {
                            throw Failure(message: "Cannot capture menu bar trigger")
                        }
                        try require(captured.screen.displayID == target.displayID, "Trigger used the active screen instead of the clicked screen")
                        try require(captured.centerX == clickX, "Missing icon did not preserve the click position")
                        // Delay both dispatch and preparation; neither may sample the live pointer again.
                        try await Task.sleep(for: .milliseconds(50))
                        await panel.show(section: .hidden, placement: captured) {
                            try? await Task.sleep(for: .milliseconds(20))
                        }
                        for width: CGFloat in [240, 320] {
                            panel.setContentSize(NSSize(width: width, height: 50))
                            let expectedX = (clickX - panel.frame.width / 2).clamped(to: target.frame.minX...(target.frame.maxX - panel.frame.width))
                            try require(abs(panel.frame.minX - expectedX) < 1, "Delayed show or resize lost the click anchor")
                            try require(panel.frame.minY >= target.frame.minY && panel.frame.maxY <= target.frame.maxY, "Panel escaped its target screen")
                            frames.append(["screen": target.localizedName, "location": location.rawValue, "clickX": clickX, "clickY": clickY, "frame": NSStringFromRect(panel.frame)])
                        }
                    }
                }
            }
            if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("ice-bar-\(target.displayID).png"))
            }
            panel.close()
        }
        let metadata = try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted, .sortedKeys])
        try metadata.write(to: directory.appendingPathComponent("panel-frames.json"))
        print("PASS: native panel lifecycle, delayed middle/edge clicks in all location modes across \(NSScreen.screens.count) screens; snapshots saved")
    }
}
#endif
