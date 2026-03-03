import SwiftUI
import Observation
import SpacetimeDB
#if canImport(AppKit)
import AppKit
#endif


struct GameEventEntry: Identifiable {
    enum Kind {
        case info
        case combat
    }

    let id: Int
    let text: String
    let kind: Kind
    let timestamp: Date
}

struct HudStatChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint.opacity(0.65))
        }
    }
}

struct HudHealthMeter: View {
    let health: UInt32

    private var fraction: Double { min(1, max(0, Double(health) / 100)) }
    private var color: Color { Color(hue: 0.33 * fraction, saturation: 0.82, brightness: 0.95) }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(health)")
                .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .frame(minWidth: 36, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
        }
    }
}

struct EventFeedView: View {
    let events: [GameEventEntry]
    var title: String = "Event Feed"
    var maxVisible: Int = 4
    var padded: Bool = false
    
    private var visibleEvents: [GameEventEntry] {
        Array(events.suffix(maxVisible).reversed())
    }

    private func fillColor(for event: GameEventEntry) -> Color {
        event.kind == .combat ? SurvivorsTheme.danger.opacity(0.60) : Color.black.opacity(0.52)
    }

    private func strokeColor(for event: GameEventEntry) -> Color {
        event.kind == .combat ? SurvivorsTheme.danger.opacity(0.4) : Color.white.opacity(0.12)
    }

    @ViewBuilder
    private func eventRow(_ event: GameEventEntry) -> some View {
        Text(event.text.uppercased())
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(fillColor(for: event))
                    .overlay(
                        Capsule().strokeBorder(strokeColor(for: event), lineWidth: 1)
                    )
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleEvents) { event in
                eventRow(event)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: events.map(\.id))
    }
}

struct MenuButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
            }
        }
        .buttonStyle(PixelButtonStyle(danger: role == .some(.destructive)))
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    static func fromId(_ id: UInt64) -> Color {
        let h = Double(id % 360) / 360.0
        return Color(hue: h, saturation: 0.72, brightness: 0.88)
    }
}
