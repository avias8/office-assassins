import SwiftUI

// MARK: - Theme

enum SurvivorsTheme {
    static let accent = Color(red: 0.05, green: 0.81, blue: 0.73)
    static let accentSecondary = Color(red: 0.98, green: 0.78, blue: 0.18)
    static let danger = Color(red: 1.0, green: 0.33, blue: 0.36)
    static let panelStroke = Color.white.opacity(0.20)
    static let panelFill = Color(red: 0.04, green: 0.08, blue: 0.14).opacity(0.84)
    static let backdropTop = Color(red: 0.03, green: 0.11, blue: 0.20)
    static let backdropBottom = Color(red: 0.03, green: 0.06, blue: 0.11)
    static let backdropGlow = Color(red: 0.04, green: 0.86, blue: 0.76).opacity(0.30)
    static let backdropGlowSecondary = Color(red: 0.99, green: 0.63, blue: 0.22).opacity(0.18)
    static let textPrimary = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let textMuted = Color(white: 0.62)
}

// MARK: - Shared UI Style

extension View {
    func pixelPanel() -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SurvivorsTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(SurvivorsTheme.panelStroke, lineWidth: 1)
                )
        )
    }

    func survivorsPanel(cornerRadius: CGFloat = 18) -> some View {
        background(SurvivorsPanelBackground(cornerRadius: cornerRadius))
    }

    func survivorsShadow() -> some View {
        shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Button Style

struct PixelButtonStyle: ButtonStyle {
    var filled: Bool = false
    var danger: Bool = false
    var accentColor: Color = SurvivorsTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNextCondensed-DemiBold", size: 14))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(fgColor)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(bgColor(configuration.isPressed))
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.10 : 0.26), radius: 8, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.978 : 1.0)
            .animation(.easeInOut(duration: 0.10), value: configuration.isPressed)
    }

    private var fgColor: Color {
        if danger && filled {
            return .white
        }
        if danger {
            return SurvivorsTheme.danger
        }
        return filled ? Color(red: 0.02, green: 0.08, blue: 0.10) : SurvivorsTheme.textPrimary
    }

    private func bgColor(_ pressed: Bool) -> Color {
        if danger && filled {
            return SurvivorsTheme.danger.opacity(pressed ? 0.80 : 0.98)
        }
        if danger {
            return SurvivorsTheme.danger.opacity(pressed ? 0.22 : 0.12)
        }
        if filled {
            return accentColor.opacity(pressed ? 0.82 : 0.98)
        }
        return Color(red: 0.08, green: 0.14, blue: 0.22).opacity(pressed ? 0.70 : 0.56)
    }

    private var borderColor: Color {
        if danger {
            return SurvivorsTheme.danger.opacity(0.88)
        }
        if filled {
            return accentColor.opacity(0.94)
        }
        return Color.white.opacity(0.34)
    }
}

// MARK: - Panel / Chip Backgrounds

struct SurvivorsChipBackground: View {
    var cornerRadius: CGFloat = 6

    var body: some View {
        SurvivorsShapeSurface(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            fallbackMaterial: .regularMaterial,
            usesLiquidGlass: true
        )
    }
}

struct SurvivorsPanelBackground: View {
    var cornerRadius: CGFloat = 18

    var body: some View {
        // Keep large panels deterministic to avoid liquid geometry morphing.
        SurvivorsShapeSurface(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            fallbackMaterial: .ultraThinMaterial,
            stroke: SurvivorsTheme.panelStroke,
            lineWidth: 1,
            usesLiquidGlass: false
        )
    }
}

struct SurvivorsShapeSurface<S: InsettableShape>: View {
    let shape: S
    var fallbackMaterial: Material
    var stroke: Color? = nil
    var lineWidth: CGFloat = 1
    var usesLiquidGlass: Bool = true

    var body: some View {
        liquidOrFallback
            .overlay {
                if let stroke {
                    shape.strokeBorder(stroke, lineWidth: lineWidth)
                }
            }
    }

    @ViewBuilder
    private var liquidOrFallback: some View {
        if usesLiquidGlass, #available(macOS 26.0, iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect()
                .clipShape(shape)
        } else {
            shape.fill(fallbackMaterial)
        }
    }
}

// MARK: - Animated Backdrop

struct SurvivorsBackdrop: View {
    // Deterministic star field using golden-ratio hashing.
    private static let stars: [(x: Double, y: Double, sz: CGFloat, spd: Double, ph: Double)] = (0..<60).map { i in
        let g = 0.6180339887498949
        return (
            x: (Double(i) * g).truncatingRemainder(dividingBy: 1.0),
            y: (Double(i * 7 + 3) * g).truncatingRemainder(dividingBy: 1.0),
            sz: CGFloat(1.5 + (Double(i * 13 + 7) * g).truncatingRemainder(dividingBy: 1.0) * 2.0),
            spd: 0.4 + (Double(i * 19 + 11) * g).truncatingRemainder(dividingBy: 1.0) * 1.4,
            ph: (Double(i * 31 + 17) * g).truncatingRemainder(dividingBy: 1.0) * .pi * 2
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let glowAX = 0.50 + 0.28 * cos(t * 0.07)
            let glowAY = 0.38 + 0.20 * sin(t * 0.05)
            let glowBX = 0.52 + 0.24 * sin(t * 0.06 + 1.3)
            let glowBY = 0.62 + 0.20 * cos(t * 0.05 + 0.8)

            ZStack {
                LinearGradient(
                    colors: [SurvivorsTheme.backdropTop, SurvivorsTheme.backdropBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Slow-scrolling pixel grid
                Canvas { ctx, size in
                    let grid: CGFloat = 64
                    let xShift = CGFloat((t * 4).truncatingRemainder(dividingBy: Double(grid)))
                    let yShift = CGFloat((t * 3).truncatingRemainder(dividingBy: Double(grid)))
                    var path = Path()

                    var x = -grid + xShift
                    while x <= size.width + grid {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += grid
                    }

                    var y = -grid + yShift
                    while y <= size.height + grid {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += grid
                    }

                    ctx.stroke(path, with: .color(SurvivorsTheme.accent.opacity(0.16)), lineWidth: 1)
                }

                // Twinkling pixel stars
                Canvas { ctx, size in
                    for star in Self.stars {
                        let alpha = 0.15 + 0.85 * (0.5 + 0.5 * sin(t * star.spd + star.ph))
                        let rect = CGRect(
                            x: star.x * size.width - star.sz / 2,
                            y: star.y * size.height - star.sz / 2,
                            width: star.sz, height: star.sz
                        )
                        ctx.fill(Path(rect), with: .color(Color.white.opacity(alpha)))
                    }
                }

                // Teal ambient glow
                RadialGradient(
                    colors: [SurvivorsTheme.backdropGlow, .clear],
                    center: UnitPoint(x: glowAX, y: glowAY),
                    startRadius: 30,
                    endRadius: 540
                )
                .blur(radius: 40)

                // Gold ambient glow
                RadialGradient(
                    colors: [SurvivorsTheme.backdropGlowSecondary, .clear],
                    center: UnitPoint(x: glowBX, y: glowBY),
                    startRadius: 24,
                    endRadius: 440
                )
                .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }
}
