import AppKit
import CoreGraphics

// A removable, click-through overlay for monitors whose hardware brightness
// cannot be reached over HDMI/DDC. It leaves the monitor's own setting intact.
@MainActor
final class VisualDimmer {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var levels: [CGDirectDisplayID: Int] = [:]

    func level(for id: CGDirectDisplayID) -> Int {
        levels[id] ?? 100
    }

    func set(_ percent: Int, for id: CGDirectDisplayID) {
        let percent = max(5, min(100, percent))
        levels[id] = percent

        guard percent < 100 else {
            windows[id]?.close()
            windows.removeValue(forKey: id)
            return
        }

        guard let screen = screen(for: id) else { return }
        let window = windows[id] ?? makeWindow(on: screen)
        windows[id] = window
        window.setFrame(screen.frame, display: true)
        // 5% still leaves the UI visible enough to undo the change.
        let opacity = 0.88 * (1 - CGFloat(percent) / 100)
        window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
        window.orderFrontRegardless()
    }

    func updateFrames() {
        for (id, percent) in Array(levels) where percent < 100 {
            set(percent, for: id)
        }
        let visibleIDs = Set(DisplayDiscovery.current().map(\.id))
        for id in Array(windows.keys) where !visibleIDs.contains(id) {
            windows[id]?.close()
            windows.removeValue(forKey: id)
            levels.removeValue(forKey: id)
        }
    }

    func clear() {
        for window in windows.values { window.close() }
        windows.removeAll()
        levels.removeAll()
    }

    private func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == id
        }
    }

    private func makeWindow(on screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        return window
    }
}
