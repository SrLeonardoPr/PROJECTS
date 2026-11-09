import SwiftUI

struct BrightnessView: View {
    @ObservedObject var model: BrightnessModel
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if model.displays.isEmpty {
                Text("No se detectaron pantallas activas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                allScreens
                Divider()
                ForEach(model.displays) { display in
                    displayControl(display)
                }
            }

            if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if model.hasVisualControl {
                Text("La atenuación visual se desactiva al salir de la app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Text("Brillo Rápido")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Salir", action: quit)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.yellow)
            Text("Brillo")
                .font(.headline)
            Spacer()
            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Actualizar pantallas")
        }
    }

    private var allScreens: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Todas las pantallas")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.allPercent)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            adjustmentRow(
                value: Binding(
                    get: { Double(model.allPercent) },
                    set: { model.setAll(to: Int($0.rounded())) }
                ),
                enabled: model.displays.contains(where: { $0.method.canAdjust }),
                decrease: { model.stepAll(by: -5) },
                increase: { model.stepAll(by: 5) }
            )
        }
    }

    private func displayControl(_ display: DisplayState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(display.method.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(display.method == .checking ? "…" : "\(display.percent)%")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            adjustmentRow(
                value: Binding(
                    get: {
                        Double(model.displays.first(where: { $0.id == display.id })?.percent ?? display.percent)
                    },
                    set: { model.setBrightness(for: display.id, to: Int($0.rounded())) }
                ),
                enabled: display.method.canAdjust,
                decrease: { model.step(display.id, by: -5) },
                increase: { model.step(display.id, by: 5) }
            )
        }
    }

    private func adjustmentRow(
        value: Binding<Double>,
        enabled: Bool,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 9) {
            Button(action: decrease) {
                Image(systemName: "minus")
                    .frame(width: 17, height: 20)
            }
            .help("Bajar 5%")
            Slider(value: value, in: 5...100, step: 1)
            Button(action: increase) {
                Image(systemName: "plus")
                    .frame(width: 17, height: 20)
            }
            .help("Subir 5%")
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
