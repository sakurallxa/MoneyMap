import WidgetKit
import SwiftUI

/// 主屏 Widget——通过 App Group UserDefaults 读取主 App 写入的总资产快照。
struct MoneyMapWidget: Widget {
    let kind: String = "MoneyMapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoneyMapWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("钱袋 · 总资产")
        .description("一眼看到全部资产 + 今日盈亏")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let totalCNY: Double
    let dailyChange: Double
    let dailyChangePct: Double
    let lastUpdated: Date?

    static let placeholder = WidgetSnapshotEntry(
        date: Date(),
        totalCNY: 108638.61,
        dailyChange: -180.24,
        dailyChangePct: -0.17,
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
        let defaults = UserDefaults(suiteName: WidgetState.appGroupID)
        return WidgetSnapshotEntry(
            date: Date(),
            totalCNY: defaults?.double(forKey: WidgetState.keyTotal) ?? 0,
            dailyChange: defaults?.double(forKey: WidgetState.keyDailyChange) ?? 0,
            dailyChangePct: defaults?.double(forKey: WidgetState.keyDailyPct) ?? 0,
            lastUpdated: defaults?.object(forKey: WidgetState.keyUpdatedAt) as? Date
        )
    }
}

struct MoneyMapWidgetView: View {
    let entry: WidgetSnapshotEntry
    @Environment(\.widgetFamily) var family

    private var pnlColor: Color {
        if entry.dailyChange > 0 { return Color(red: 0.902, green: 0.224, blue: 0.275) }
        if entry.dailyChange < 0 { return Color(red: 0.106, green: 0.498, blue: 0.278) }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            Text("总资产")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(formatTotal())
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: entry.dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(formattedChange())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text(formattedPct())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(pnlColor)

            if let updated = entry.lastUpdated {
                Spacer(minLength: 0)
                Text("更新 \(timeText(updated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatTotal() -> String {
        let v = entry.totalCNY
        if v == 0 { return "¥-" }
        if abs(v) >= 100_000_000 {
            return String(format: "¥%.2f亿", v / 100_000_000)
        }
        if abs(v) >= 10_000 {
            return String(format: "¥%.2f万", v / 10_000)
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return "¥" + (f.string(from: NSNumber(value: v)) ?? "0")
    }

    private func formattedChange() -> String {
        let sign = entry.dailyChange >= 0 ? "+" : ""
        return sign + String(format: "¥%.2f", entry.dailyChange)
    }

    private func formattedPct() -> String {
        let sign = entry.dailyChangePct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", entry.dailyChangePct))%"
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
