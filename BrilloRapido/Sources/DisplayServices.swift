import CoreGraphics
import Foundation

// macOS does not expose a public API for the MacBook's hardware brightness.
// Resolve the system's DisplayServices symbols at runtime so the app can report
// an unavailable control instead of failing to launch if macOS changes them.
enum DisplayServices {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeFunction = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias ChangedFunction = @convention(c) (CGDirectDisplayID, Double) -> Int32

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getFunction: GetFunction? = symbol("DisplayServicesGetBrightness")
    private static let setFunction: SetFunction? = symbol("DisplayServicesSetBrightness")
    private static let canChangeFunction: CanChangeFunction? = symbol("DisplayServicesCanChangeBrightness")
    private static let changedFunction: ChangedFunction? = symbol("DisplayServicesBrightnessChanged")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static func canControl(_ id: CGDirectDisplayID) -> Bool {
        guard getFunction != nil, setFunction != nil else { return false }
        if CGDisplayIsBuiltin(id) != 0 { return true }
        return canChangeFunction?(id) == true
    }

    static func get(_ id: CGDirectDisplayID) -> Double? {
        guard let getFunction else { return nil }
        var value: Float = 0
        guard getFunction(id, &value) == 0, value.isFinite else { return nil }
        return Double(max(0, min(1, value)))
    }

    @discardableResult
    static func set(_ id: CGDirectDisplayID, to value: Double) -> Bool {
        guard let setFunction else { return false }
        let bounded = Float(max(0, min(1, value)))
        guard setFunction(id, bounded) == 0 else { return false }
        // Keep macOS's brightness cache in step with the hardware value.
        _ = changedFunction?(id, Double(bounded))
        return true
    }
}
