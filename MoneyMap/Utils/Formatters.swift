import Foundation
import SwiftUI

enum CurrencyFormatter {
    static let cny: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CNY"
        f.currencySymbol = "¥"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f
    }()

    static func cnyString(_ value: Double) -> String {
        cny.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func cnyShort(_ value: Double) -> String {
        let abs = abs(value)
        if abs >= 100_000_000 {
            return String(format: "¥%.2f亿", value / 100_000_000)
        } else if abs >= 10_000 {
            return String(format: "¥%.2f万", value / 10_000)
        } else {
            return cnyString(value)
        }
    }

    /// 用于狭窄 tile 的紧凑格式:小于 1 万显示整数,大于 1 万用万/亿单位。
    static func cnyTile(_ value: Double, signed: Bool = false) -> String {
        let absV = abs(value)
        let signPrefix: String
        if signed {
            signPrefix = value > 0 ? "+" : (value < 0 ? "-" : "")
        } else {
            signPrefix = value < 0 ? "-" : ""
        }
        if absV >= 100_000_000 {
            return "\(signPrefix)¥\(String(format: "%.2f亿", absV / 100_000_000))"
        } else if absV >= 10_000 {
            return "\(signPrefix)¥\(String(format: "%.2f万", absV / 10_000))"
        } else {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return "\(signPrefix)¥\(f.string(from: NSNumber(value: absV)) ?? "0")"
        }
    }

    static func signedCNY(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + cnyString(value)
    }

    static func percent(_ value: Double, decimals: Int = 2) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimals)f", value))%"
    }

    static func shares(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        return f.string(from: NSNumber(value: value)) ?? "0.00"
    }

    static func price(_ value: Double, currency: CurrencyCode = .cny) -> String {
        let prefix = currency.symbol
        return "\(prefix)\(String(format: "%.4f", value))"
    }
}

enum DateUtil {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static let timeShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let chartAxis: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    static func relative(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days)天前" }
        return dateOnly.string(from: date)
    }
}

/// 全局统一掩码字符串(hideBalance 启用时显示)。
/// 5 个全角间隔点 — 视觉上比 `****` 更高级
let kHiddenAmountMask = "¥ · · · · ·"
let kHiddenPercentMask = "·· %"

extension Double {
    /// 货币格式(带千分位 + ¥ + 2 位小数),支持 hideBalance 一键掩码。
    func formattedCNY(hidden: Bool = false) -> String {
        hidden ? kHiddenAmountMask : CurrencyFormatter.cnyString(self)
    }

    /// 带正负号的货币格式。
    func formattedSignedCNY(hidden: Bool = false) -> String {
        hidden ? kHiddenAmountMask : CurrencyFormatter.signedCNY(self)
    }

    /// 百分比格式(带正负号),支持 hideBalance 一键掩码。
    func formattedPercent(hidden: Bool = false, decimals: Int = 2) -> String {
        hidden ? kHiddenPercentMask : CurrencyFormatter.percent(self, decimals: decimals)
    }

    /// VoiceOver 友好的金额读法 — 把 ¥1,234,567.89 读作「123 万 4 千 5 百 67 点 89 元」。
    /// hideBalance 时返回「已隐藏」。
    func accessibilityAmountLabel(prefix: String = "金额", hidden: Bool = false) -> String {
        if hidden { return "\(prefix) 已隐藏" }
        let n = abs(self)
        let sign = self < 0 ? "负" : ""
        let yi = Int(n / 100_000_000)
        let wan = Int((n.truncatingRemainder(dividingBy: 100_000_000)) / 10_000)
        let yuan = Int(n.truncatingRemainder(dividingBy: 10_000))
        var parts: [String] = []
        if yi > 0 { parts.append("\(yi) 亿") }
        if wan > 0 { parts.append("\(wan) 万") }
        if yuan > 0 || parts.isEmpty { parts.append("\(yuan)") }
        return "\(prefix) \(sign)\(parts.joined(separator: " ")) 元"
    }

    /// VoiceOver 友好的百分比读法 —「上涨 1 点 23 个百分点」。
    func accessibilityPercentLabel(hidden: Bool = false) -> String {
        if hidden { return "涨跌幅 已隐藏" }
        let abs1 = abs(self)
        let dir = self > 0 ? "上涨" : (self < 0 ? "下跌" : "持平")
        return "\(dir) \(String(format: "%.2f", abs1)) 个百分点"
    }
}

extension Color {
    static var pnlPositive: Color { Color(hex: "#E63946") }
    static var pnlNegative: Color { Color(hex: "#1B7F47") }

    static func pnlColor(_ value: Double) -> Color {
        if value > 0 { return .pnlPositive }
        if value < 0 { return .pnlNegative }
        return .secondary
    }

    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let pageBackground = Color(.systemGroupedBackground)

    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
