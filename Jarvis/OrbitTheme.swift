import AppKit
import SwiftUI

// MARK: - Theme

enum OrbitColorTheme: String, CaseIterable, Identifiable {
    case matrix
    case cyan
    case amber
    case violet
    case red
    case fireside
    case neptune
    case pastel
    case saturn
    case pride
    case glass
    case minimal

    static let storageKey = "orbit.colorTheme"
    static let darkBackgroundStorageKey = "orbit.darkBackgroundEnabled"
    static let glassTransparencyStorageKey = "orbit.glassTransparency"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .matrix: return "Matrix"
        case .cyan: return "Ciano"
        case .amber: return "Âmbar"
        case .violet: return "Violeta"
        case .red: return "Vermelho"
        case .fireside: return "Fireside"
        case .neptune: return "Neptune"
        case .pastel: return "Pastel"
        case .saturn: return "Saturn"
        case .pride: return "Pride"
        case .glass: return "Glass"
        case .minimal: return "Minimal"
        }
    }

    var backgroundComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .matrix: return (0.07, 0.08, 0.10)
        case .cyan: return (0.045, 0.075, 0.09)
        case .amber: return (0.095, 0.075, 0.045)
        case .violet: return (0.07, 0.055, 0.095)
        case .red: return (0.10, 0.045, 0.05)
        case .fireside: return (0.847, 0.831, 0.737)
        case .neptune: return (0.561, 0.851, 0.984)
        case .pastel: return (1.0, 0.965, 0.745)
        case .saturn: return (0.914, 0.831, 0.616)
        case .pride: return (0.035, 0.025, 0.075)
        case .glass: return (0.0, 0.0, 0.0)
        case .minimal: return (0.0, 0.0, 0.0)
        }
    }

    var panelComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .matrix: return (0.12, 0.13, 0.16)
        case .cyan: return (0.075, 0.12, 0.14)
        case .amber: return (0.145, 0.115, 0.07)
        case .violet: return (0.115, 0.085, 0.155)
        case .red: return (0.145, 0.075, 0.085)
        case .fireside: return (0.443, 0.259, 0.212)
        case .neptune: return (0.427, 0.545, 0.753)
        case .pastel: return (1.0, 0.820, 0.875)
        case .saturn: return (0.765, 0.565, 0.290)
        case .pride: return (0.105, 0.055, 0.165)
        case .glass: return (0.0, 0.0, 0.0)
        case .minimal: return (0.0, 0.0, 0.0)
        }
    }

    var accentComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .matrix: return (0.714, 1.0, 0.180)
        case .cyan: return (0.12, 0.90, 1.0)
        case .amber: return (1.0, 0.70, 0.18)
        case .violet: return (0.78, 0.48, 1.0)
        case .red: return (1.0, 0.28, 0.34)
        case .fireside: return (0.537, 0.102, 0.063)
        case .neptune: return (0.322, 0.353, 1.0)
        case .pastel: return (1.0, 0.545, 0.725)
        case .saturn: return (0.729, 0.651, 0.494)
        case .pride: return (1.0, 0.929, 0.0)
        case .glass: return (0.74, 0.96, 1.0)
        case .minimal: return (0.88, 0.88, 0.88)
        }
    }

    var assistantActiveComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .matrix: return (0.02, 0.62, 1.0)
        case .cyan: return (0.62, 1.0, 0.92)
        case .amber: return (1.0, 0.46, 0.12)
        case .violet: return (0.42, 0.86, 1.0)
        case .red: return (1.0, 0.76, 0.24)
        case .fireside: return (0.862, 0.510, 0.212)
        case .neptune: return (0.290, 0.710, 0.710)
        case .pastel: return (1.0, 0.875, 0.360)
        case .saturn: return (0.894, 0.765, 0.482)
        case .pride: return (0.0, 0.302, 1.0)
        case .glass: return (1.0, 1.0, 1.0)
        case .minimal: return (1.0, 1.0, 1.0)
        }
    }

    var background: Color {
        usesPureGlass ? .clear : Color(red: backgroundComponents.red, green: backgroundComponents.green, blue: backgroundComponents.blue)
    }

    var panel: Color {
        usesPureGlass ? .clear : Color(red: panelComponents.red, green: panelComponents.green, blue: panelComponents.blue)
    }

    var accent: Color {
        return Color(red: accentComponents.red, green: accentComponents.green, blue: accentComponents.blue)
    }

    var usesLightGlass: Bool {
        switch self {
        case .fireside, .neptune, .pastel, .saturn:
            return true
        default:
            return false
        }
    }

    var usesPureGlass: Bool {
        self == .glass
    }

    var supportsDarkBackgroundOverride: Bool {
        usesLightGlass == false && usesPureGlass == false
    }

    var usesMinimalDetails: Bool {
        self == .minimal
    }

    var swatchColors: [Color] {
        switch self {
        case .fireside:
            return [
                Color(red: 0.847, green: 0.831, blue: 0.737),
                Color(red: 0.862, green: 0.510, blue: 0.212),
                Color(red: 0.537, green: 0.102, blue: 0.063)
            ]
        case .neptune:
            return [
                Color(red: 0.561, green: 0.851, blue: 0.984),
                Color(red: 0.290, green: 0.710, blue: 0.710),
                Color(red: 0.427, green: 0.545, blue: 0.753),
                Color(red: 0.322, green: 0.353, blue: 1.0)
            ]
        case .pastel:
            return [
                Color(red: 1.0, green: 0.965, blue: 0.745),
                Color(red: 1.0, green: 0.820, blue: 0.875),
                Color(red: 1.0, green: 0.545, blue: 0.725)
            ]
        case .saturn:
            return [
                Color(red: 0.914, green: 0.831, blue: 0.616),
                Color(red: 0.894, green: 0.765, blue: 0.482),
                Color(red: 0.765, green: 0.565, blue: 0.290),
                Color(red: 0.976, green: 0.925, blue: 0.663),
                Color(red: 0.729, green: 0.651, blue: 0.494)
            ]
        case .pride:
            return [
                Color(red: 0.894, green: 0.012, blue: 0.012),
                Color(red: 1.0, green: 0.549, blue: 0.0),
                Color(red: 1.0, green: 0.929, blue: 0.0),
                Color(red: 0.0, green: 0.502, blue: 0.149),
                Color(red: 0.0, green: 0.302, blue: 1.0),
                Color(red: 0.459, green: 0.027, blue: 0.529)
            ]
        case .glass:
            return [
                .white.opacity(0.78),
                Color(red: 0.74, green: 0.96, blue: 1.0),
                .clear
            ]
        case .minimal:
            return [
                .black,
                .white.opacity(0.88)
            ]
        default:
            return [background, panel, accent]
        }
    }
}

enum MatrixTheme {
    static var current: OrbitColorTheme {
        OrbitColorTheme(rawValue: UserDefaults.standard.string(forKey: OrbitColorTheme.storageKey) ?? "") ?? .matrix
    }

    static var usesDarkBackgroundOverride: Bool {
        UserDefaults.standard.bool(forKey: OrbitColorTheme.darkBackgroundStorageKey)
            && current.supportsDarkBackgroundOverride
    }

    static var glassTransparency: Double {
        let storedValue = UserDefaults.standard.object(forKey: OrbitColorTheme.glassTransparencyStorageKey) as? Double ?? 0.65
        return min(1.0, max(0.0, storedValue))
    }

    static var glassOpacity: Double {
        1.0 - glassTransparency
    }

    static var background: Color { current == .pride ? .clear : (usesDarkBackgroundOverride ? .black : current.background) }
    static var panel: Color { current == .pride ? .clear : current.panel }
    static var appBackground: Color {
        current.usesPureGlass || current == .pride ? .clear : background
    }
    static var appPanel: Color {
        current.usesPureGlass || current == .pride ? .clear : panel
    }
    static var green: Color { current.accent }
    static var isPride: Bool { current == .pride }
    static var prideColors: [Color] {
        [
            Color(red: 0.894, green: 0.012, blue: 0.012),
            Color(red: 1.0, green: 0.549, blue: 0.0),
            Color(red: 1.0, green: 0.929, blue: 0.0),
            Color(red: 0.0, green: 0.502, blue: 0.149),
            Color(red: 0.0, green: 0.302, blue: 1.0),
            Color(red: 0.459, green: 0.027, blue: 0.529)
        ]
    }
    static var prideGradient: LinearGradient {
        LinearGradient(colors: prideColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var prideSoftGradient: LinearGradient {
        LinearGradient(colors: prideColors.map { $0.opacity(0.22) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var prideBackdropGradient: LinearGradient {
        LinearGradient(colors: prideColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func iconSystemName(_ systemName: String) -> String {
        guard current.usesMinimalDetails else { return systemName }
        return minimalStrokeIconOverrides[systemName] ?? systemName.replacingOccurrences(of: ".fill", with: "")
    }

    private static let minimalStrokeIconOverrides: [String: String] = [
        "tray.full.fill": "tray.full",
        "tray.and.arrow.down.fill": "tray.and.arrow.down",
        "square.grid.2x2.fill": "square.grid.2x2",
        "exclamationmark.triangle.fill": "exclamationmark.triangle",
        "person.crop.circle.fill": "person.crop.circle"
    ]

    static func font(size: CGFloat, weight: Font.Weight) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
    static func font(_ style: Font.TextStyle) -> Font {
        return .system(style, design: .monospaced)
    }
    static var lightText: Color {
        switch current {
        case .fireside, .neptune:
            return current.background
        default:
            return current.accent
        }
    }
    static var darkText: Color {
        switch current {
        case .fireside, .neptune:
            return current.accent
        default:
            return .black
        }
    }
    static var textOnDark: Color {
        switch current {
        case .fireside, .neptune:
            return lightText
        case .pride:
            return .white
        default:
            return current.accent
        }
    }
    static var textOnGlass: Color {
        current.usesLightGlass ? textOnLight : textOnDark
    }
    static var secondaryTextOnGlass: Color {
        textOnGlass.opacity(current.usesPureGlass ? 0.82 : (current.usesMinimalDetails ? 0.54 : (current.usesLightGlass ? 0.78 : 0.62)))
    }
    static var textOnPanel: Color {
        textOnGlass
    }
    static var textOnLight: Color {
        darkText
    }
    static var textOnAccent: Color {
        switch current {
        case  .neptune:
            return .white
        default:
            return .black
        }
    }
    static var settingsText: Color {
        textOnGlass
    }
    static var glassFallbackBackground: Color {
        if current.usesPureGlass || current == .pride { return .clear }
        if current.usesMinimalDetails { return .black }
        return current.usesLightGlass ? current.background.opacity(0.18) : current.panel
    }
    static var glassSurfaceBackground: Color {
        if current.usesPureGlass || current == .pride { return .clear }
        if current.usesMinimalDetails { return .black }
        return current.usesLightGlass ? current.background.opacity(0.12) : current.panel.opacity(0.78)
    }
    static var assistantActiveColor: Color {
        let components = current.assistantActiveComponents
        return Color(red: components.red, green: components.green, blue: components.blue)
    }
    static let evaLogoCyan = Color(red: 0.16, green: 0.92, blue: 1.0)
    static let evaLogoBlue = Color(red: 0.28, green: 0.48, blue: 1.0)
    static let evaLogoViolet = Color(red: 0.68, green: 0.28, blue: 1.0)
    static let evaLogoMagenta = Color(red: 1.0, green: 0.34, blue: 0.82)
    static let evaGlowGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    static let evaGlowOrange = Color(red: 1.0, green: 0.314, blue: 0.0)
    static let evaGlowSoftGreen = Color(red: 0.847, green: 0.961, blue: 0.847)
    static let evaGlassText = Color(red: 0.847, green: 0.961, blue: 0.847)
    static let evaGlassSecondaryText = Color(red: 0.70, green: 0.92, blue: 0.70)
    static var evaLogoGlowColors: [Color] {
        [
            evaLogoCyan,
            evaLogoBlue,
            evaLogoViolet,
            evaLogoMagenta,
            .white.opacity(0.95),
            evaLogoCyan
        ]
    }
    static var colorScheme: ColorScheme {
        current.usesLightGlass ? .light : .dark
    }
    static var nsAppearance: NSAppearance {
        NSAppearance(named: current.usesLightGlass ? .aqua : .darkAqua) ?? NSApp.effectiveAppearance
    }

    static var nsBackground: NSColor {
        guard current.usesPureGlass == false else { return .clear }
        if usesDarkBackgroundOverride { return .black }
        let components = current.backgroundComponents
        return NSColor(red: components.red, green: components.green, blue: components.blue, alpha: 1.0)
    }

}

extension Image {
    init(orbitSystemName systemName: String) {
        self.init(systemName: MatrixTheme.iconSystemName(systemName))
    }
}

struct PrideDiagonalStripeBackground: View {
    private let stripeWidth: CGFloat = 132
    private let stripeAngle = Angle.degrees(34)

    var body: some View {
        GeometryReader { proxy in
            let diagonalLength = hypot(proxy.size.width, proxy.size.height)
            let totalSpan = diagonalLength * 2.4
            let stripeCount = max(18, Int(totalSpan / stripeWidth) + MatrixTheme.prideColors.count * 2)

            ZStack {
                ForEach(0..<stripeCount, id: \.self) { index in
                    Rectangle()
                        .fill(MatrixTheme.prideColors[index % MatrixTheme.prideColors.count])
                        .frame(width: stripeWidth, height: diagonalLength * 2.6)
                        .rotationEffect(stripeAngle)
                        .offset(x: CGFloat(index) * stripeWidth - totalSpan / 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

@available(macOS 26.0, *)
private struct OrbitNativeGlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = cornerRadius
        view.tintColor = nil
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.style = .regular
        nsView.cornerRadius = cornerRadius
        nsView.tintColor = nil
    }
}

private struct OrbitGlassCapsuleModifier: ViewModifier {
    let tint: Color
    let prominent: Bool
    @AppStorage(OrbitColorTheme.storageKey) private var selectedThemeRawValue = OrbitColorTheme.matrix.rawValue
    @AppStorage(OrbitColorTheme.glassTransparencyStorageKey) private var glassTransparency = 0.65

    private var selectedTheme: OrbitColorTheme {
        OrbitColorTheme(rawValue: selectedThemeRawValue) ?? .matrix
    }

    private var glass: Glass {
        if selectedTheme.usesPureGlass {
            return Glass.clear.interactive()
        }

        if selectedTheme == .pride {
            return Glass.clear.tint(Color(red: 0.459, green: 0.027, blue: 0.529).opacity(0.18)).interactive()
        }

        let tintOpacity: Double
        if selectedTheme.usesMinimalDetails {
            tintOpacity = 0
        } else {
            tintOpacity = selectedTheme.usesLightGlass ? 0.04 : 0.10
        }
        return Glass.regular.tint(tint.opacity(tintOpacity)).interactive()
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if selectedTheme == .pride {
                content
                    .environment(\.colorScheme, .dark)
                    .glassEffect(glass)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(prominent ? 0.48 : 0.30), lineWidth: 1)
                    )
                    .contentShape(Capsule())
                    .id("orbit-pride-capsule-\(selectedThemeRawValue)-\(prominent)")
            } else if selectedTheme.usesPureGlass {
                content
                    .environment(\.colorScheme, selectedTheme.usesLightGlass ? .light : .dark)
                    .glassEffect(glass)
                    .contentShape(Capsule())
                    .id("orbit-glass-capsule-\(selectedThemeRawValue)-\(selectedTheme.usesLightGlass)")
            } else {
                content
                    .environment(\.colorScheme, selectedTheme.usesLightGlass ? .light : .dark)
                    .background(MatrixTheme.glassSurfaceBackground, in: Capsule())
                    .glassEffect(glass)
                    .contentShape(Capsule())
                    .id("orbit-glass-capsule-\(selectedThemeRawValue)-\(selectedTheme.usesLightGlass)")
            }
        } else {
            if selectedTheme == .pride {
                content
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(prominent ? 0.48 : 0.30), lineWidth: 1)
                    )
                    .contentShape(Capsule())
            } else {
                content
                    .background(MatrixTheme.glassFallbackBackground, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(selectedTheme.usesMinimalDetails ? (prominent ? 0.28 : 0.14) : (prominent ? 0.9 : 0.65)), lineWidth: 1)
                    )
                    .contentShape(Capsule())
            }
        }
    }
}

private struct OrbitGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strokeOpacity: Double
    let isInteractive: Bool
    @AppStorage(OrbitColorTheme.storageKey) private var selectedThemeRawValue = OrbitColorTheme.matrix.rawValue
    @AppStorage(OrbitColorTheme.glassTransparencyStorageKey) private var glassTransparency = 0.65

    private var selectedTheme: OrbitColorTheme {
        OrbitColorTheme(rawValue: selectedThemeRawValue) ?? .matrix
    }

    private var glass: Glass {
        if selectedTheme.usesPureGlass {
            return isInteractive ? Glass.clear.interactive() : Glass.clear
        }

        if selectedTheme == .pride {
            let prideGlass = Glass.clear.tint(Color(red: 0.459, green: 0.027, blue: 0.529).opacity(0.18))
            return isInteractive ? prideGlass.interactive() : prideGlass
        }

        let tintOpacity: Double
        if selectedTheme.usesMinimalDetails {
            tintOpacity = 0
        } else {
            tintOpacity = selectedTheme.usesLightGlass ? 0.035 : 0.08
        }
        let tintedGlass = Glass.regular.tint(MatrixTheme.green.opacity(tintOpacity))
        return isInteractive ? tintedGlass.interactive() : tintedGlass
    }

    private var glassStrokeMultiplier: Double {
        selectedTheme.usesPureGlass ? 1.0 : 1.0
    }

    private var effectiveCornerRadius: CGFloat {
        max(cornerRadius + 10, 24)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if selectedTheme == .pride {
                content
                    .environment(\.colorScheme, .dark)
                    .glassEffect(
                        glass,
                        in: .rect(cornerRadius: effectiveCornerRadius)
                    )
                    .id("orbit-pride-panel-\(selectedThemeRawValue)-\(effectiveCornerRadius)-\(isInteractive)")
                    .overlay(
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .stroke(.white.opacity(max(0.18, strokeOpacity * 0.52)), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
            } else if selectedTheme.usesPureGlass {
                content
                    .environment(\.colorScheme, selectedTheme.usesLightGlass ? .light : .dark)
                    .glassEffect(
                        glass,
                        in: .rect(cornerRadius: effectiveCornerRadius)
                    )
                    .id("orbit-glass-panel-\(selectedThemeRawValue)-\(selectedTheme.usesLightGlass)-\(effectiveCornerRadius)-\(isInteractive)")
                    .overlay(
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(strokeOpacity * glassStrokeMultiplier * 0.46),
                                        MatrixTheme.green.opacity(strokeOpacity * glassStrokeMultiplier * 0.34),
                                        .white.opacity(strokeOpacity * glassStrokeMultiplier * 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
            } else {
                if selectedTheme.usesLightGlass {
                    content
                        .environment(\.colorScheme, .light)
                        .background(
                            MatrixTheme.glassSurfaceBackground,
                            in: .rect(cornerRadius: effectiveCornerRadius)
                        )
                        .glassEffect(
                            glass,
                            in: .rect(cornerRadius: effectiveCornerRadius)
                        )
                        .id("orbit-glass-panel-\(selectedThemeRawValue)-\(selectedTheme.usesLightGlass)-\(effectiveCornerRadius)-\(isInteractive)")
                        .overlay(
                            RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(strokeOpacity * glassStrokeMultiplier * 0.08),
                                            MatrixTheme.green.opacity(strokeOpacity * glassStrokeMultiplier * 0.22)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
                } else {
                    content
                        .environment(\.colorScheme, .dark)
                        .background(
                            MatrixTheme.glassSurfaceBackground,
                            in: .rect(cornerRadius: effectiveCornerRadius)
                        )
                        .id("orbit-solid-panel-\(selectedThemeRawValue)-\(effectiveCornerRadius)-\(isInteractive)")
                        .overlay(
                            RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(strokeOpacity * glassStrokeMultiplier * (selectedTheme.usesMinimalDetails ? 0.04 : 0.18)),
                                            MatrixTheme.green.opacity(strokeOpacity * glassStrokeMultiplier * (selectedTheme.usesMinimalDetails ? 0.06 : 0.24))
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
                }
            }
        } else {
            if selectedTheme == .pride {
                content
                    .background(
                        .ultraThinMaterial,
                        in: .rect(cornerRadius: effectiveCornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .stroke(.white.opacity(max(0.18, strokeOpacity * 0.52)), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
            } else {
                content
                    .background(MatrixTheme.glassFallbackBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .stroke(MatrixTheme.green.opacity(selectedTheme.usesMinimalDetails ? strokeOpacity * 0.10 : strokeOpacity), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
            }
        }
    }
}

private struct OrbitEVAClearGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strokeOpacity: Double
    let isInteractive: Bool

    private var effectiveCornerRadius: CGFloat {
        max(cornerRadius + 10, 24)
    }

    private var glass: Glass {
        isInteractive ? Glass.clear.interactive() : Glass.clear
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .environment(\.colorScheme, MatrixTheme.colorScheme)
                .glassEffect(glass, in: .rect(cornerRadius: effectiveCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    MatrixTheme.evaGlowSoftGreen.opacity(strokeOpacity * 0.42),
                                    MatrixTheme.evaGlowGreen.opacity(strokeOpacity * 0.44),
                                    MatrixTheme.evaGlowOrange.opacity(strokeOpacity * 0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        } else {
            content
                .background(MatrixTheme.glassFallbackBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                        .stroke(MatrixTheme.evaGlowGreen.opacity(strokeOpacity * 0.62), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        }
    }
}

private struct OrbitEVADiffuseGlowModifier: ViewModifier {
    let cornerRadius: CGFloat
    let spread: CGFloat
    let opacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var glowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var effectiveSpread: CGFloat {
        spread * 0.5
    }

    private func primaryGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.88), location: 0.00),
                .init(color: MatrixTheme.evaGlowSoftGreen.opacity(0.92), location: 0.22),
                .init(color: MatrixTheme.evaGlowOrange.opacity(0.90), location: 0.48),
                .init(color: MatrixTheme.evaGlowSoftGreen.opacity(0.82), location: 0.72),
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.88), location: 1.00)
            ]),
            center: .center,
            angle: angle
        )
    }

    private func blurGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.0), location: 0.00),
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.54), location: 0.12),
                .init(color: MatrixTheme.evaGlowSoftGreen.opacity(0.48), location: 0.30),
                .init(color: MatrixTheme.evaGlowOrange.opacity(0.0), location: 0.43),
                .init(color: MatrixTheme.evaGlowOrange.opacity(0.56), location: 0.58),
                .init(color: MatrixTheme.evaGlowSoftGreen.opacity(0.42), location: 0.78),
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.0), location: 1.00)
            ]),
            center: .center,
            angle: angle
        )
    }

    private func counterGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: MatrixTheme.evaGlowOrange.opacity(0.44), location: 0.00),
                .init(color: MatrixTheme.evaGlowSoftGreen.opacity(0.30), location: 0.32),
                .init(color: MatrixTheme.evaGlowGreen.opacity(0.40), location: 0.66),
                .init(color: MatrixTheme.evaGlowOrange.opacity(0.44), location: 1.00)
            ]),
            center: .center,
            angle: angle
        )
    }

    private func angle(for date: Date, duration: TimeInterval, degrees: Double) -> Angle {
        guard reduceMotion == false else { return .degrees(0) }
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        return .degrees(progress * degrees)
    }


    func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation) { timeline in
                    let primaryAngle = angle(for: timeline.date, duration: 6.8, degrees: 360)
                    let counterAngle = angle(for: timeline.date, duration: 9.4, degrees: -360)

                    ZStack {
                        glowShape
                            .stroke(blurGradient(angle: primaryAngle), lineWidth: 9)
                            .opacity(opacity * 0.58)
                            .blur(radius: effectiveSpread * 0.86)

                        glowShape
                            .stroke(blurGradient(angle: counterAngle), lineWidth: 6)
                            .opacity(opacity * 0.52)
                            .blur(radius: effectiveSpread * 0.48)

                        glowShape
                            .stroke(primaryGradient(angle: primaryAngle + .degrees(28)), lineWidth: 2.8)
                            .opacity(opacity * 0.50)
                            .blur(radius: effectiveSpread * 0.26)
                    }
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func orbitGlassCapsule(tint: Color = .cyan, prominent: Bool = false) -> some View {
        modifier(OrbitGlassCapsuleModifier(tint: tint, prominent: prominent))
    }

    func orbitGlassPanel(cornerRadius: CGFloat = 8, strokeOpacity: Double = 0.36, isInteractive: Bool = true) -> some View {
        modifier(OrbitGlassPanelModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, isInteractive: isInteractive))
    }

    func orbitEVAClearGlassPanel(cornerRadius: CGFloat, strokeOpacity: Double = 0.48, isInteractive: Bool = true) -> some View {
        modifier(OrbitEVAClearGlassPanelModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, isInteractive: isInteractive))
    }

    func orbitEVADiffuseGlow(cornerRadius: CGFloat, spread: CGFloat = 24, opacity: Double = 0.76) -> some View {
        modifier(OrbitEVADiffuseGlowModifier(cornerRadius: cornerRadius, spread: spread, opacity: opacity))
    }
}
