import SwiftUI
#if os(macOS)
import AppKit
#endif

enum OrbitTheme {
    static let displayFontScaleKey = "orbitplane.displayFontScale"

    static let bgVoid = Color(red: 0.0196, green: 0.0235, blue: 0.0392)
    static let bgDeep = Color(red: 0.0392, green: 0.0510, blue: 0.0784)
    static let bgSurface = Color(red: 0.0667, green: 0.0784, blue: 0.1098)
    static let bgCard = Color(red: 0.0863, green: 0.1020, blue: 0.1412)
    static let bgCardHover = Color(red: 0.1098, green: 0.1333, blue: 0.1882)

    static let neonCyan = Color(red: 0.0, green: 0.8980, blue: 1.0)
    static let neonGreen = Color(red: 0.7216, green: 1.0, blue: 0.2353)
    static let neonPink = Color(red: 1.0, green: 0.1804, blue: 0.5569)
    static let neonOrange = Color(red: 1.0, green: 0.7137, blue: 0.1529)
    static let neonYellow = neonOrange
    static let neonPurple = Color(red: 0.5451, green: 0.3608, blue: 0.9647)

    static let textPrimary = Color(red: 0.8941, green: 0.9255, blue: 0.9686)
    static let textSecondary = Color(red: 0.5451, green: 0.5882, blue: 0.6706)
    static let textMuted = Color(red: 0.3529, green: 0.3961, blue: 0.5020)

    static let border = Color(red: 0.1176, green: 0.1373, blue: 0.1882)
    static let borderStrong = Color(red: 0.1647, green: 0.1922, blue: 0.2510)

    static let radiusSharp: CGFloat = 0
    static let radiusSoft: CGFloat = 2
    static let radiusControl: CGFloat = 4

    static let labelTracking: CGFloat = 2.1

    static var displayFontScale: CGFloat {
        let stored = UserDefaults.standard.double(forKey: displayFontScaleKey)
        let scale = stored == 0 ? 1.0 : stored
        return CGFloat(min(max(scale, 0.82), 1.34))
    }

    static func scaledFontSize(_ size: CGFloat) -> CGFloat {
        (size * displayFontScale).rounded(.toNearestOrAwayFromZero)
    }

    static func displayFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaledFontSize(size), weight: weight, design: .monospaced)
    }

    static func labelFont(_ size: CGFloat = 10, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaledFontSize(size), weight: weight, design: .monospaced)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledFontSize(size), weight: weight, design: .monospaced)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaledFontSize(size), weight: weight)
    }
}

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.28), radius: radius * 0.6)
    }
}

struct CyberCard: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .fill(isHovered ? OrbitTheme.bgCardHover : OrbitTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .stroke(
                        isHovered ? OrbitTheme.borderStrong : OrbitTheme.border,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(isHovered ? OrbitTheme.neonCyan.opacity(0.85) : OrbitTheme.borderStrong)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.32))
                    .frame(height: 1)
            }
    }
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 8) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }

    func cyberCard(isHovered: Bool = false) -> some View {
        modifier(CyberCard(isHovered: isHovered))
    }

    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}

struct PointingHandCursor: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        content
        #endif
    }
}

struct AppBackgroundGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OrbitTheme.bgVoid,
                    OrbitTheme.bgDeep,
                    OrbitTheme.bgSurface.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    OrbitTheme.bgCardHover.opacity(0.52),
                    OrbitTheme.bgDeep.opacity(0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 620
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.24),
                    Color.clear,
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24

            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(OrbitTheme.neonCyan.opacity(0.035)), lineWidth: 0.5)
                x += spacing
            }

            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(OrbitTheme.neonCyan.opacity(0.035)), lineWidth: 0.5)
                y += spacing
            }
        }
    }
}

struct DotGridBackground: View {
    var dotColor: Color = OrbitTheme.borderStrong
    var spacing: CGFloat = 20
    var opacity: Double = 0.5

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor.opacity(opacity)))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 3
            }
            context.stroke(path, with: .color(.white.opacity(0.018)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct OrbitPlaneMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Hexagon()
                .stroke(OrbitTheme.neonPurple.opacity(0.55), lineWidth: 1)
                .frame(width: size, height: size)

            Hexagon()
                .stroke(OrbitTheme.neonPurple.opacity(0.9), lineWidth: 1)
                .background(
                    Hexagon()
                        .fill(OrbitTheme.neonPurple.opacity(0.055))
                )
                .frame(width: size * 0.74, height: size * 0.74)

            Ellipse()
                .stroke(OrbitTheme.neonCyan.opacity(0.72), lineWidth: 1)
                .frame(width: size * 0.78, height: size * 0.28)
                .rotationEffect(.degrees(-18))

            Ellipse()
                .stroke(OrbitTheme.neonPurple.opacity(0.46), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(width: size * 0.52, height: size * 0.72)

            Path { path in
                let center = CGPoint(x: size / 2, y: size / 2)
                path.move(to: CGPoint(x: center.x, y: center.y - size * 0.13))
                path.addLine(to: CGPoint(x: center.x + size * 0.11, y: center.y + size * 0.10))
                path.addLine(to: CGPoint(x: center.x, y: center.y + size * 0.02))
                path.addLine(to: CGPoint(x: center.x - size * 0.11, y: center.y + size * 0.10))
                path.closeSubpath()
            }
            .fill(OrbitTheme.neonCyan)
            .frame(width: size, height: size)

            Circle()
                .fill(OrbitTheme.neonGreen)
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: size * 0.30, y: -size * 0.15)
                .neonGlow(OrbitTheme.neonGreen, radius: 5)

            Circle()
                .fill(OrbitTheme.neonPink)
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: -size * 0.29, y: size * 0.25)
        }
        .frame(width: size, height: size)
        .neonGlow(OrbitTheme.neonCyan, radius: 6)
    }
}

struct RadarScope: View {
    var sweepAngle: Angle = .degrees(-24)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                RadialGradient(
                    colors: [
                        OrbitTheme.neonCyan.opacity(0.16),
                        OrbitTheme.bgVoid.opacity(0.2),
                        OrbitTheme.bgVoid.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: side * 0.48
                )

                Canvas { context, size in
                    for step in 1...4 {
                        let radius = side * CGFloat(step) * 0.105
                        let rect = CGRect(x: center.x - radius, y: center.y - radius * 0.44, width: radius * 2, height: radius * 0.88)
                        context.stroke(Path(ellipseIn: rect), with: .color(OrbitTheme.borderStrong.opacity(0.8)), lineWidth: 0.7)
                    }

                    var axes = Path()
                    axes.move(to: CGPoint(x: center.x - side * 0.42, y: center.y))
                    axes.addLine(to: CGPoint(x: center.x + side * 0.42, y: center.y))
                    axes.move(to: CGPoint(x: center.x, y: center.y - side * 0.32))
                    axes.addLine(to: CGPoint(x: center.x, y: center.y + side * 0.32))
                    context.stroke(axes, with: .color(OrbitTheme.border.opacity(0.7)), lineWidth: 0.7)
                }

                Wedge(startAngle: sweepAngle, endAngle: sweepAngle + .degrees(38))
                    .fill(
                        LinearGradient(
                            colors: [OrbitTheme.neonCyan.opacity(0.02), OrbitTheme.neonCyan.opacity(0.26)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: side * 0.86, height: side * 0.86)
                    .position(center)

                StatusNode(color: OrbitTheme.neonGreen, size: 7)
                    .position(x: center.x + side * 0.25, y: center.y - side * 0.12)

                StatusNode(color: OrbitTheme.neonPink, size: 5)
                    .position(x: center.x - side * 0.22, y: center.y + side * 0.17)

                StatusNode(color: OrbitTheme.neonOrange, size: 5)
                    .position(x: center.x + side * 0.08, y: center.y - side * 0.27)
            }
        }
    }
}

struct Wedge: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let x = rect.minX
        let y = rect.minY

        var path = Path()
        path.move(to: CGPoint(x: x + width * 0.5, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y + height * 0.25))
        path.addLine(to: CGPoint(x: x + width, y: y + height * 0.75))
        path.addLine(to: CGPoint(x: x + width * 0.5, y: y + height))
        path.addLine(to: CGPoint(x: x, y: y + height * 0.75))
        path.addLine(to: CGPoint(x: x, y: y + height * 0.25))
        path.closeSubpath()
        return path
    }
}

struct CornerBrackets: ViewModifier {
    var color: Color = OrbitTheme.neonCyan
    var length: CGFloat = 10

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let l = length

                    path.move(to: CGPoint(x: 0, y: l))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: l, y: 0))

                    path.move(to: CGPoint(x: width - l, y: 0))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: l))

                    path.move(to: CGPoint(x: 0, y: height - l))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: l, y: height))

                    path.move(to: CGPoint(x: width - l, y: height))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: width, y: height - l))
                }
                .stroke(color.opacity(0.62), lineWidth: 1)
            }
        }
    }
}

extension View {
    func cornerBrackets(color: Color = OrbitTheme.neonCyan, length: CGFloat = 10) -> some View {
        modifier(CornerBrackets(color: color, length: length))
    }
}

struct BlinkingCursor: View {
    var color: Color = OrbitTheme.neonCyan
    var size: CGFloat = 12
    @State private var isVisible = true

    var body: some View {
        Text("▌")
            .font(OrbitTheme.monoFont(size, weight: .bold))
            .foregroundStyle(color)
            .opacity(isVisible ? 1 : 0.18)
            .onAppear {
                withAnimation(.linear(duration: 0.82).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}

struct StatusNode: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.55), lineWidth: 1)
                .frame(width: size * 2.0, height: size * 2.0)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .neonGlow(color, radius: 6)
        }
    }
}

struct SignalGlyph: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 11

    var body: some View {
        Text(symbol)
            .font(OrbitTheme.monoFont(size, weight: .bold))
            .foregroundStyle(color)
            .neonGlow(color, radius: 3)
            .frame(width: size + 4, alignment: .center)
    }
}

struct OrbitTag: View {
    let text: String
    var color: Color = OrbitTheme.textMuted

    var body: some View {
        Text(text)
            .font(OrbitTheme.labelFont(9, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(OrbitTheme.bgDeep)
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.26), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}
