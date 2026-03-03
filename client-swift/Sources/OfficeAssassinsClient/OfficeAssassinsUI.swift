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
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.custom("AvenirNextCondensed-DemiBold", size: 10))
                .foregroundStyle(tint.opacity(0.72))
            Text(value)
                .font(.custom("AvenirNextCondensed-Heavy", size: 14))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.42), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HudHealthMeter: View {
    let health: UInt32

    private var clampedHealth: Double {
        min(100, max(0, Double(health)))
    }

    private var healthFraction: Double {
        clampedHealth / 100
    }

    private var healthColor: Color {
        Color(hue: 0.33 * healthFraction, saturation: 0.82, brightness: 0.95)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("HP")
                    .font(.custom("AvenirNextCondensed-Heavy", size: 10))
                    .foregroundStyle(healthColor.opacity(0.80))
                Text("\(Int(clampedHealth))/100")
                    .font(.custom("AvenirNextCondensed-Heavy", size: 12))
                    .foregroundStyle(healthColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                    Rectangle()
                        .fill(healthColor)
                        .frame(width: max(4, geo.size.width * healthFraction))
                }
            }
            .frame(height: 7)
            .overlay(Rectangle().strokeBorder(healthColor.opacity(0.50), lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(white: 0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct EventFeedView: View {
    let events: [GameEventEntry]
    var title: String = "Event Feed"
    var maxVisible: Int = 8
    var padded: Bool = false
    private let eventLifetime: TimeInterval = 18
    private let fadeDuration: TimeInterval = 10
    private let popInDuration: TimeInterval = 0.35

    struct RenderedEvent: Identifiable {
        let entry: GameEventEntry
        let opacity: Double
        let scale: CGFloat
        let offsetY: CGFloat
        var id: Int { entry.id }
    }

    private func renderedEvents(at now: Date) -> [RenderedEvent] {
        Array(events.suffix(maxVisible).reversed()).compactMap { event in
            let age = now.timeIntervalSince(event.timestamp)
            guard age >= 0, age < eventLifetime else { return nil }

            let fadeStart = eventLifetime - fadeDuration
            let opacity: Double
            if age <= fadeStart {
                opacity = 1.0
            } else {
                opacity = max(0, (eventLifetime - age) / max(0.001, fadeDuration))
            }

            let popProgress = min(1, max(0, age / popInDuration))
            let popEase = 1 - pow(1 - popProgress, 3)
            let scale = 0.94 + (0.06 * popEase)
            let offsetY = 8 * (1 - popEase)

            return RenderedEvent(
                entry: event,
                opacity: opacity,
                scale: scale,
                offsetY: offsetY
            )
        }
    }

    private var listHeight: CGFloat {
        // Stable height prevents panel-edge jitter as items appear/disappear.
        CGFloat(maxVisible) * 18 + 4
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let visible = renderedEvents(at: timeline.date)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("AvenirNextCondensed-DemiBold", size: 11))
                    .foregroundStyle(SurvivorsTheme.textMuted)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)

                ZStack(alignment: .topLeading) {
                    if visible.isEmpty {
                        Text("No recent events")
                            .font(.custom("AvenirNextCondensed-Medium", size: 11))
                            .foregroundStyle(Color(white: 0.35))
                            .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visible) { item in
                            HStack(spacing: 6) {
                                Text(item.entry.kind == .combat ? "►" : "·")
                                    .font(.custom("AvenirNextCondensed-Heavy", size: 10))
                                    .foregroundStyle(item.entry.kind == .combat ? SurvivorsTheme.accentSecondary : SurvivorsTheme.accent)
                                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                                Text(item.entry.text)
                                    .font(.custom("AvenirNextCondensed-Medium", size: 11))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .shadow(color: .black, radius: 1.5, x: 1, y: 1)
                                Spacer(minLength: 0)
                            }
                            .opacity(item.opacity)
                            .scaleEffect(item.scale, anchor: .leading)
                            .offset(y: item.offsetY)
                        }
                    }
                }
                .frame(height: listHeight, alignment: .topLeading)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: visible.map(\.id))
            .padding(padded ? 10 : 0)
        }
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
