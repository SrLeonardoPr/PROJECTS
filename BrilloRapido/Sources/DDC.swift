import CoreGraphics
import Foundation

enum DDC {
    static var helperURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/m1ddc")
    }

    private static func run(_ arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else { return nil }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }

        if finished.wait(timeout: .now() + 5) == .timedOut {
            if process.isRunning { process.terminate() }
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func selector(for id: CGDirectDisplayID) -> [String] {
        ["display", "id=\(Int32(bitPattern: id))"]
    }

    static func currentValue(for id: CGDirectDisplayID) -> Int? {
        guard let output = run(selector(for: id) + ["get", "luminance"]),
              let value = Int(output), value >= 0 else { return nil }
        return value
    }

    static func maximumValue(for id: CGDirectDisplayID) -> Int? {
        guard let output = run(selector(for: id) + ["max", "luminance"]),
              let value = Int(output), value > 0 else { return nil }
        return value
    }

    static func setValue(_ value: Int, for id: CGDirectDisplayID) -> Bool {
        let result = run(selector(for: id) + ["set", "luminance", String(value)])
        return result?.hasPrefix("Writing ") == true
    }
}
