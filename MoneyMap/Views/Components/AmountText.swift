import SwiftUI

struct AmountText: View {
    let amount: Double
    var size: Size = .medium
    var showSign: Bool = false
    var prefix: String = "¥"
    var hidden: Bool = false

    enum Size {
        case hero, large, medium, small

        var font: Font {
            switch self {
            case .hero: return .system(size: 44, weight: .bold)
            case .large: return .system(size: 28, weight: .bold)
            case .medium: return .system(size: 17, weight: .semibold)
            case .small: return .system(size: 13, weight: .semibold)
            }
        }
    }

    var body: some View {
        Text(displayText)
            .font(size.font)
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private var displayText: String {
        if hidden { return kHiddenAmountMask }
        if showSign {
            let sign = amount >= 0 ? "+" : ""
            let absText = numberFormatter.string(from: NSNumber(value: abs(amount))) ?? "0.00"
            return prefix + sign + (amount < 0 ? "-" : "") + absText
        }
        return prefix + (numberFormatter.string(from: NSNumber(value: amount)) ?? "0.00")
    }

    private var color: Color {
        if !showSign { return .primary }
        return Color.pnlColor(amount)
    }

    private var numberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }
}

struct PercentText: View {
    let percent: Double
    var size: Font = .subheadline.weight(.semibold)
    var hidden: Bool = false

    var body: some View {
        Text(text)
            .font(size)
            .monospacedDigit()
            .foregroundStyle(hidden ? .secondary : Color.pnlColor(percent))
    }

    private var text: String {
        if hidden { return "**%" }
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", percent))%"
    }
}
