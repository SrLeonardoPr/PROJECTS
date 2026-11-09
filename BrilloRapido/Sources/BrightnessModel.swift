import AppKit
import Combine
import CoreGraphics

enum ControlMethod: Equatable {
    case native
    case ddc
    case visual
    case checking
    case unavailable

    var description: String {
        switch self {
        case .native: return "Brillo real de la pantalla"
        case .ddc: return "Brillo real del monitor"
        case .visual: return "Atenuación visual"
        case .checking: return "Comprobando el monitor…"
        case .unavailable: return "Control no disponible"
        }
    }

    var canAdjust: Bool {
        self != .checking && self != .unavailable
    }
}

struct DisplayState: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    var percent: Int
    var method: ControlMethod
    var hardwareMaximum: Int = 100
}

@MainActor
final class BrightnessModel: ObservableObject {
    @Published private(set) var displays: [DisplayState] = []
    @Published private(set) var message: String?

    private let dimmer = VisualDimmer()
    private let ddcQueue = DispatchQueue(label: "BrilloRapido.DDC", qos: .userInitiated)
    private var pendingWrites: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var writeSequence: [CGDirectDisplayID: Int] = [:]
    private var refreshGeneration = 0

    var allPercent: Int {
        let adjustable = displays.filter { $0.method.canAdjust }
        guard !adjustable.isEmpty else { return 100 }
        return Int((Double(adjustable.map(\.percent).reduce(0, +)) / Double(adjustable.count)).rounded())
    }

    var hasVisualControl: Bool {
        displays.contains { $0.method == .visual }
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let previous = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0) })
        let connected = DisplayDiscovery.current()

        displays = connected.map { display in
            if DisplayServices.canControl(display.id),
               let brightness = DisplayServices.get(display.id) {
                dimmer.set(100, for: display.id)
                return DisplayState(
                    id: display.id,
                    name: display.name,
                    isBuiltIn: display.isBuiltIn,
                    percent: Int((brightness * 100).rounded()),
                    method: .native
                )
            }

            if display.isBuiltIn {
                return DisplayState(
                    id: display.id,
                    name: display.name,
                    isBuiltIn: true,
                    percent: previous[display.id]?.percent ?? dimmer.level(for: display.id),
                    method: .visual
                )
            }

            return DisplayState(
                id: display.id,
                name: display.name,
                isBuiltIn: false,
                percent: previous[display.id]?.percent ?? dimmer.level(for: display.id),
                method: .checking
            )
        }

        dimmer.updateFrames()
        let externalIDs = connected.filter { !$0.isBuiltIn && !DisplayServices.canControl($0.id) }.map(\.id)
        guard !externalIDs.isEmpty else { return }

        ddcQueue.async { [weak self] in
            let readings: [(CGDirectDisplayID, Int?, Int?)] = externalIDs.map { id in
                let current = DDC.currentValue(for: id)
                let maximum = current == nil ? nil : (DDC.maximumValue(for: id) ?? 100)
                return (id, current, maximum)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.refreshGeneration == generation else { return }
                for (id, current, maximum) in readings {
                    guard let index = self.displays.firstIndex(where: { $0.id == id }),
                          self.displays[index].method == .checking else { continue }
                    if let current, let maximum, maximum > 0 {
                        self.displays[index].method = .ddc
                        self.displays[index].hardwareMaximum = maximum
                        self.displays[index].percent = Int((Double(current) * 100 / Double(maximum)).rounded())
                        self.dimmer.set(100, for: id)
                    } else {
                        self.displays[index].method = .visual
                        self.displays[index].percent = self.dimmer.level(for: id)
                    }
                }
            }
        }
    }

    func setAll(to percent: Int) {
        for id in displays.filter({ $0.method.canAdjust }).map(\.id) {
            setBrightness(for: id, to: percent)
        }
    }

    func stepAll(by points: Int) {
        let targets = displays.filter { $0.method.canAdjust }.map { ($0.id, $0.percent + points) }
        for (id, target) in targets { setBrightness(for: id, to: target) }
    }

    func step(_ id: CGDirectDisplayID, by points: Int) {
        guard let state = displays.first(where: { $0.id == id }) else { return }
        setBrightness(for: id, to: state.percent + points)
    }

    func setBrightness(for id: CGDirectDisplayID, to percent: Int) {
        guard let index = displays.firstIndex(where: { $0.id == id }),
              displays[index].method.canAdjust else { return }
        let percent = max(5, min(100, percent))
        displays[index].percent = percent
        message = nil

        switch displays[index].method {
        case .native:
            if !DisplayServices.set(id, to: Double(percent) / 100) {
                displays[index].method = .visual
                dimmer.set(percent, for: id)
                message = "La pantalla pasó a atenuación visual."
            }
        case .ddc:
            scheduleDDCWrite(for: id, percent: percent, maximum: displays[index].hardwareMaximum)
        case .visual:
            dimmer.set(percent, for: id)
        case .checking, .unavailable:
            break
        }
    }

    func stop() {
        for item in pendingWrites.values { item.cancel() }
        pendingWrites.removeAll()
        dimmer.clear()
    }

    private func scheduleDDCWrite(for id: CGDirectDisplayID, percent: Int, maximum: Int) {
        pendingWrites[id]?.cancel()
        let sequence = (writeSequence[id] ?? 0) + 1
        writeSequence[id] = sequence
        let target = Int((Double(percent) * Double(maximum) / 100).rounded())
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ddcQueue.async { [weak self] in
                let success = DDC.setValue(target, for: id)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.writeSequence[id] == sequence else { return }
                    self.pendingWrites.removeValue(forKey: id)
                    guard !success,
                          let index = self.displays.firstIndex(where: { $0.id == id }),
                          self.displays[index].method == .ddc else { return }
                    let desired = self.displays[index].percent
                    self.displays[index].method = .visual
                    self.dimmer.set(desired, for: id)
                    self.message = "El monitor pasó a atenuación visual."
                }
            }
        }
        pendingWrites[id] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(140), execute: item)
    }
}
