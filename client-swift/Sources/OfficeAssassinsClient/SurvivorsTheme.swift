import SwiftUI

// MARK: - Theme (Old-School Flash Game)

enum SurvivorsTheme {
    // Primary palette – free-to-play flash arena.
    static let accent = Color(red: 1.00, green: 0.42, blue: 0.10)         // Electric orange
    static let accentSecondary = Color(red: 0.15, green: 0.92, blue: 0.85) // Neon cyan
    static let warning = Color(red: 1.00, green: 0.84, blue: 0.10)        // Prize yellow
    static let danger = Color(red: 1.00, green: 0.23, blue: 0.30)

    // Surface / chrome
    static let panelStroke = Color(red: 0.96, green: 0.39, blue: 0.20).opacity(0.75)
    static let panelFill = Color(red: 0.02, green: 0.06, blue: 0.12).opacity(0.94)
    static let panelFillSecondary = Color(red: 0.03, green: 0.10, blue: 0.18).opacity(0.94)
    static let cardFill = Color(red: 0.08, green: 0.14, blue: 0.23)
    static let cardSelected = accent.opacity(0.24)

    // Background accents
    static let backdropTop = Color(red: 0.04, green: 0.08, blue: 0.16)
    static let backdropBottom = Color(red: 0.02, green: 0.03, blue: 0.08)
    static let backdropGlow = accent.opacity(0.12)
    static let backdropGlowSecondary = accentSecondary.opacity(0.10)

    // Typography
    static let textPrimary = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let textMuted = Color(red: 0.51, green: 0.66, blue: 0.78)

    static let borderWeight: CGFloat = 2.5

    // Fonts – chunky, bold, arcade-like
    static func heavy(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func demiBold(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func medium(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

// MARK: - Shared UI Style

extension View {
    func pixelPanel() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SurvivorsTheme.panelFillSecondary, SurvivorsTheme.panelFill],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SurvivorsTheme.panelStroke, lineWidth: SurvivorsTheme.borderWeight)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        .padding(2)
                )
        )
    }

    func survivorsPanel(cornerRadius: CGFloat = 18) -> some View {
        background(SurvivorsPanelBackground(cornerRadius: cornerRadius))
    }

    func survivorsShadow() -> some View {
        shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    func tvFocusableTile(
        cornerRadius: CGFloat = 10,
        focusedScale: CGFloat = 1.05,
        focusTint: Color = SurvivorsTheme.accentSecondary
    ) -> some View {
        #if os(tvOS)
        modifier(
            TVFocusableTileModifier(
                cornerRadius: cornerRadius,
                focusedScale: focusedScale,
                focusTint: focusTint
            )
        )
        #else
        self
        #endif
    }
}

#if os(tvOS)
private struct TVFocusableTileModifier: ViewModifier {
    let cornerRadius: CGFloat
    let focusedScale: CGFloat
    let focusTint: Color

    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(focusTint.opacity(isFocused ? 0.95 : 0), lineWidth: 3)
                    .padding(-3)
            }
            .shadow(
                color: isFocused ? focusTint.opacity(0.75) : .clear,
                radius: isFocused ? 20 : 0
            )
            .scaleEffect(isFocused ? focusedScale : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
#endif

// MARK: - Button Style

struct PixelButtonStyle: ButtonStyle {
    var filled: Bool = false
    var danger: Bool = false
    var accentColor: Color = SurvivorsTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        // Inner view so @Environment(\.isFocused) works (tvOS focus engine)
        Inner(configuration: configuration, filled: filled, danger: danger, accentColor: accentColor)
    }

    private struct Inner: View {
        let configuration: Configuration
        let filled: Bool
        let danger: Bool
        let accentColor: Color
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .font(.custom("AvenirNextCondensed-DemiBold", size: 14))
                .tracking(0.3)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .foregroundStyle(fgColor)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bgColor(configuration.isPressed))
                        .overlay(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(focusBorderColor, lineWidth: isFocused ? 3 : 1.8)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(configuration.isPressed ? 0.0 : 0.28))
                        .frame(height: 5)
                        .padding(.horizontal, 2)
                        .offset(y: 3)
                        .blur(radius: 0.4)
                }
                .shadow(
                    color: isFocused
                        ? focusGlowColor.opacity(0.75)
                        : Color.black.opacity(configuration.isPressed ? 0.08 : 0.28),
                    radius: isFocused ? 18 : 7,
                    x: 0, y: isFocused ? 0 : 4
                )
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.04 : 1.0))
                .animation(.easeInOut(duration: 0.10), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }

        private var fgColor: Color {
            if danger && filled { return .white }
            if danger { return SurvivorsTheme.danger }
            return filled ? Color(red: 0.02, green: 0.08, blue: 0.10) : SurvivorsTheme.textPrimary
        }

        private func bgColor(_ pressed: Bool) -> Color {
            if danger && filled { return SurvivorsTheme.danger.opacity(pressed ? 0.80 : 0.98) }
            if danger { return SurvivorsTheme.danger.opacity(pressed ? 0.22 : 0.12) }
            if filled { return accentColor.opacity(pressed ? 0.82 : 0.98) }
            return Color(red: 0.07, green: 0.16, blue: 0.28).opacity(pressed ? 0.82 : 0.68)
        }

        private var borderColor: Color {
            if danger { return SurvivorsTheme.danger.opacity(0.88) }
            if filled { return accentColor.opacity(0.94) }
            return Color.white.opacity(0.34)
        }

        // When focused on tvOS, use a brighter/accent border
        private var focusBorderColor: Color {
            guard isFocused else { return borderColor }
            if danger { return SurvivorsTheme.danger }
            return filled ? accentColor : SurvivorsTheme.accent
        }

        private var focusGlowColor: Color {
            if danger { return SurvivorsTheme.danger }
            return accentColor
        }
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
            lineWidth: SurvivorsTheme.borderWeight,
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
        if usesLiquidGlass, #available(macOS 26.0, iOS 26.0, tvOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect()
                .clipShape(shape)
        } else {
            shape.fill(fallbackMaterial)
        }
    }
}

// MARK: - Animated Backdrop (Old-School Flash)

struct SurvivorsBackdrop: View {
    var body: some View {
        ZStack {
            // Flat dark gradient — office-at-midnight vibe
            LinearGradient(
                colors: [SurvivorsTheme.backdropTop, SurvivorsTheme.backdropBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle cross-hatch / graph-paper texture
            Canvas { ctx, size in
                let spacing: CGFloat = 28
                var path = Path()

                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }

                ctx.stroke(path, with: .color(Color.white.opacity(0.03)), lineWidth: 1)
            }

            // Warm vignette at centre – subtle
            RadialGradient(
                colors: [SurvivorsTheme.accent.opacity(0.06), .clear],
                center: .center,
                startRadius: 60,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}
