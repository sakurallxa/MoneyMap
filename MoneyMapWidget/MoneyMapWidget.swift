import WidgetKit
import SwiftUI

/// 与主 App 共享的 App Group / UserDefaults keys。
/// ⚠️ 必须与主 App 的 WidgetState 完全一致。
private enum WidgetKeys {
    static let appGroupID = "group.com.lusansui.MoneyMap"
    static let keyTotal = "widgetTotalCNY"
    static let keyDailyChange = "widgetDailyChange"
    static let keyDailyPct = "widgetDailyPct"
    static let keyUpdatedAt = "widgetUpdatedAt"
}

// MARK: - Widget 自有调色板 (Widget 是独立 extension,不能引用主 App 的 Theme.swift)
// 与 HeroPnLCard 同款 hero1/2/3 + 米→金渐变 + 金箔 hairline,保持视觉一致。
private enum WidgetPalette {
    static let hero1 = Color(red: 22/255, green: 20/255, blue: 15/255)   // #16140F
    static let hero2 = Color(red: 34/255, green: 26/255, blue: 17/255)   // #221A11
    static let hero3 = Color(red: 46/255, green: 33/255, blue: 23/255)   // #2E2117
    static let bronze = Color(red: 200/255, green: 149/255, blue: 109/255) // #C8956D
    static let cream = Color(red: 251/255, green: 239/255, blue: 210/255)  // #FBEFD2
    static let goldMid = Color(red: 234/255, green: 208/255, blue: 154/255) // #EAD09A

    /// 红涨绿跌 — 与主 App 一致
    static let pnlUp = Color(red: 0.902, green: 0.224, blue: 0.275)    // #E63946
    static let pnlDown = Color(red: 0.106, green: 0.498, blue: 0.278)  // #1B7F47

    /// Hero 卡背景渐变
    static let heroBackground = LinearGradient(
        colors: [hero1, hero2, hero3],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 主数字米→金渐变(¥ + 数字)
    static let creamGold = LinearGradient(
        colors: [cream, goldMid, bronze],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 金箔 hairline 两端透明,中段金色
    static let goldHairline = LinearGradient(
        colors: [
            bronze.opacity(0.0),
            bronze.opacity(0.55),
            cream.opacity(0.85),
            bronze.opacity(0.55),
            bronze.opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Widget

struct MoneyMapWidget: Widget {
    let kind: String = "MoneyMapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoneyMapWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        WidgetPalette.heroBackground
                        // 右上角金色高光,模拟 Hero 卡的奢华感
                        RadialGradient(
                            colors: [
                                WidgetPalette.bronze.opacity(0.28),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.88, y: 0.12),
                            startRadius: 0,
                            endRadius: 120
                        )
                        // 左下角浅金箔光晕
                        RadialGradient(
                            colors: [
                                WidgetPalette.cream.opacity(0.10),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.14, y: 0.90),
                            startRadius: 0,
                            endRadius: 110
                        )
                    }
                }
        }
        .configurationDisplayName("钱袋 · 总资产")
        .description("一眼看到全部资产 + 今日盈亏")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Data

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let totalCNY: Double
    let dailyChange: Double
    let dailyChangePct: Double
    let lastUpdated: Date?

    static let placeholder = WidgetSnapshotEntry(
        date: Date(),
        totalCNY: 615090,
        dailyChange: -6467.76,
        dailyChangePct: -1.04,
        lastUpdated: Date()
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> WidgetSnapshotEntry {
        let defaults = UserDefaults(suiteName: WidgetKeys.appGroupID)
        return WidgetSnapshotEntry(
            date: Date(),
            totalCNY: defaults?.double(forKey: WidgetKeys.keyTotal) ?? 0,
            dailyChange: defaults?.double(forKey: WidgetKeys.keyDailyChange) ?? 0,
            dailyChangePct: defaults?.double(forKey: WidgetKeys.keyDailyPct) ?? 0,
            lastUpdated: defaults?.object(forKey: WidgetKeys.keyUpdatedAt) as? Date
        )
    }
}

// MARK: - View

struct MoneyMapWidgetView: View {
    let entry: WidgetSnapshotEntry
    @Environment(\.widgetFamily) var family

    private var pnlColor: Color {
        if entry.dailyChange > 0 { return WidgetPalette.pnlUp }
        if entry.dailyChange < 0 { return WidgetPalette.pnlDown }
        return WidgetPalette.cream.opacity(0.7)
    }

    /// 主数字字号 — small / medium 自适应
    private var totalFontSize: CGFloat {
        family == .systemSmall ? 26 : 36
    }

    /// ¥ 字号:数字 × 0.55(锁死比例,与 MoneyText.hero 一致)
    private var currencyFontSize: CGFloat {
        totalFontSize * 0.55
    }

    /// PnL 行 文字字号
    private var pnlFontSize: CGFloat {
        family == .systemSmall ? 11 : 13
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 eyebrow:● 总资产 · TOTAL
            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetPalette.creamGold)
                    .frame(width: 5, height: 5)
                Text("总资产 · TOTAL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Spacer(minLength: family == .systemSmall ? 4 : 8)

            // 主数字 — 米→金渐变
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: currencyFontSize, weight: .bold))
                    .foregroundStyle(WidgetPalette.creamGold.opacity(0.85))
                Text(formatTotalDigits())
                    .font(.system(size: totalFontSize, weight: .heavy))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.creamGold)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }
            .shadow(color: WidgetPalette.bronze.opacity(0.18), radius: 6, x: 0, y: 2)

            // 金箔 hairline
            Rectangle()
                .fill(WidgetPalette.goldHairline)
                .frame(height: 0.6)
                .padding(.vertical, family == .systemSmall ? 6 : 8)

            // PnL 行:↗︎/↘︎ + ¥金额 + 百分比 — 紧凑,monospaced,不折行
            HStack(spacing: 3) {
                Image(systemName: entry.dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: pnlFontSize - 1, weight: .bold))
                Text(formattedChange())
                    .font(.system(size: pnlFontSize, weight: .semibold))
                    .monospacedDigit()
                Text(formattedPct())
                    .font(.system(size: pnlFontSize, weight: .semibold))
                    .monospacedDigit()
                    .opacity(0.85)
            }
            .foregroundStyle(pnlColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            // 更新时间
            if let updated = entry.lastUpdated {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                    Text("更新 \(timeText(updated))")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(WidgetPalette.cream.opacity(0.42))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 格式化

    /// 仅返回数字部分(¥ 在外部单独渲染,确保渐变一致)
    private func formatTotalDigits() -> String {
        let v = entry.totalCNY
        if v == 0 { return "-" }
        if abs(v) >= 100_000_000 {
            return String(format: "%.2f亿", v / 100_000_000)
        }
        if abs(v) >= 10_000 {
            return String(format: "%.2f万", v / 10_000)
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }

    /// 紧凑金额:大额走 万/亿,small Widget 上避免溢出
    private func formattedChange() -> String {
        let v = entry.dailyChange
        let sign = v >= 0 ? "+" : "-"
        let abs_v = abs(v)
        if abs_v >= 10_000 {
            return sign + String(format: "¥%.2f万", abs_v / 10_000)
        }
        return sign + String(format: "¥%.2f", abs_v)
    }

    private func formattedPct() -> String {
        let v = entry.dailyChangePct
        let sign = v >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", v))%"
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
