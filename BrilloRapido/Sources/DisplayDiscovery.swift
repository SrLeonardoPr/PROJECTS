import AppKit
import CoreGraphics

struct ConnectedDisplay {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
}

enum DisplayDiscovery {
    static func current() -> [ConnectedDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            return []
        }

        var names: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            names[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
        }

        return ids.prefix(Int(count)).map { id in
            let builtIn = CGDisplayIsBuiltin(id) != 0
            return ConnectedDisplay(
                id: id,
                name: names[id] ?? (builtIn ? "Pantalla del Mac" : "Monitor externo"),
                isBuiltIn: builtIn
            )
        }
    }
}
