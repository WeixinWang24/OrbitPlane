import SwiftUI

public enum OPColor {
    public static let void = Color(red: 0.0196, green: 0.0235, blue: 0.0392)
    public static let base = Color(red: 0.0392, green: 0.0510, blue: 0.0784)
    public static let elevated1 = Color(red: 0.0667, green: 0.0784, blue: 0.1098)
    public static let elevated2 = Color(red: 0.0863, green: 0.1020, blue: 0.1412)
    public static let elevated3 = Color(red: 0.1098, green: 0.1333, blue: 0.1882)

    public static let foreground1 = Color(red: 0.8941, green: 0.9255, blue: 0.9686)
    public static let foreground2 = Color(red: 0.5451, green: 0.5882, blue: 0.6706)
    public static let foreground3 = Color(red: 0.3529, green: 0.3961, blue: 0.5020)
    public static let foreground4 = Color(red: 0.2275, green: 0.2627, blue: 0.3451)

    public static let cyan = Color(red: 0.0, green: 0.8980, blue: 1.0)
    public static let lime = Color(red: 0.7216, green: 1.0, blue: 0.2353)
    public static let magenta = Color(red: 1.0, green: 0.1804, blue: 0.5569)
    public static let amber = Color(red: 1.0, green: 0.7137, blue: 0.1529)
    public static let violet = Color(red: 0.5451, green: 0.3608, blue: 0.9647)
}

public enum OPFont {
    public static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    public static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
