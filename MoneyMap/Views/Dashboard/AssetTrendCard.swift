import SwiftUI
import Charts

/// 总资产走势卡。
/// 信息层级:
///   行 1:¥总资产(实时)+ 「今日 +¥X · +Y%」
///   行 2:RangeTabs (日/周/月/今年/全部)
///   行 3:折线图(按 range.bucket 聚合期末值;最末点替换为实时值)
///   行 4:中文 x 轴标签 (3–4 个均匀分布)
struct AssetTrendCard: View {
    let snapshots: [DailySnapshot]
    let totalAssetsCNY: Double
    let todayDelta: Double
    let todayPct: Double
    @Binding var range: TrendRange
    var hideBalance: Bool = false

    private var points: [TrendPoint] {
        AssetTrendBucketing.bucket(
            snapshots: snapshots,
            currentValue: totalAssetsCNY,
            range: range
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow
            RangeTabsView(range: $range, dark: false)

            if points.count >= 2 {
                chart
                axisLabelsRow
            } else {
                Text("数据不足")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    // MARK: - 顶部:¥ + 今日

    private var topRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(hideBalance ? "¥· · · · ·" : "¥\(formatNumber(totalAssetsCNY))")
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.5)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityLabel(totalAssetsCNY.accessibilityAmountLabel(prefix: "总资产", hidden: hideBalance))

            Spacer()

            HStack(spacing: 4) {
                Text("今日")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text(hideBalance ? "¥····" : (todayDelta >= 0 ? "+" : "-") + "¥\(formatNumber(abs(todayDelta)))")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.pnlColor(todayDelta))
                Text(hideBalance ? "··%" : String(format: "%+.2f%%", todayPct))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.pnlColor(todayDelta))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(hideBalance
                ? "今日盈亏 已隐藏"
                : "今日 \(todayDelta.accessibilityAmountLabel(prefix: todayDelta >= 0 ? "盈利" : "亏损")) · \(todayPct.accessibilityPercentLabel())")
        }
    }

    // MARK: - chart

    @ViewBuilder
    private var chart: some View {
        Chart(points) { p in
            LineMark(
                x: .value("日期", p.date),
                y: .value("总资产", p.value)
            )
            .foregroundStyle(Theme.Palette.accent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))

            AreaMark(
                x: .value("日期", p.date),
                y: .value("总资产", p.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.Palette.accent.opacity(0.35), Theme.Palette.accent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: 120)
    }

    // MARK: - x 轴标签

    /// 取 3–4 个均匀分布的 tick,中文格式由 range 决定。
    private var axisLabelsRow: some View {
        let labels = axisLabels()
        return HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if idx < labels.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private func axisLabels() -> [String] {
        guard points.count >= 2 else { return [] }
        let n = points.count
        // 目标 tick 数:最多 4,最少 2
        let target = min(4, max(2, n))
        // 均匀挑 target 个索引
        var indices: [Int] = []
        for i in 0..<target {
            let pos = Double(i) * Double(n - 1) / Double(target - 1)
            indices.append(Int(pos.rounded()))
        }
        // 去重(短序列下索引可能重复)
        var seen = Set<Int>()
        let uniq = indices.filter { seen.insert($0).inserted }
        return uniq.map { formatAxisDate(points[$0].date) }
    }

    private func formatAxisDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        switch range {
        case .day:   f.dateFormat = "M月d日"
        case .week:  f.dateFormat = "M月"
        case .month: f.dateFormat = "yy年M月"
        case .ytd:   f.dateFormat = "M月"
        case .all:   f.dateFormat = "yy年"
        }
        return f.string(from: d)
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

// MARK: - 聚合工具

/// 走势图上的一个点(已按 range.bucket 聚合的期末值)。
struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum AssetTrendBucketing {
    /// 把按天的 DailySnapshot 序列按 range.bucket 聚合为「期末值」点序列。
    /// - 最后一个 bucket 用 `currentValue` 覆盖,保证图末端 = hero 实时总资产。
    static func bucket(
        snapshots: [DailySnapshot],
        currentValue: Double,
        range: TrendRange
    ) -> [TrendPoint] {
        let cal = Calendar.current
        guard let start = range.startDate else { return [] }

        let inRange = snapshots
            .filter { $0.date >= start }
            .sorted { $0.date < $1.date }

        let keyFn: (Date) -> Date = { d in bucketKey(d, bucket: range.bucket, calendar: cal) }

        // group by key, take period-end (最晚) snapshot for each bucket
        var groups: [Date: DailySnapshot] = [:]
        for s in inRange {
            let k = keyFn(s.date)
            if let prev = groups[k] {
                if s.date > prev.date { groups[k] = s }
            } else {
                groups[k] = s
            }
        }

        var points = groups
            .map { TrendPoint(date: $0.value.date, value: $0.value.totalValueCNY) }
            .sorted { $0.date < $1.date }

        // 把"当前 bucket"的末值替换为实时值(若不存在则追加)
        let now = Date()
        let currentKey = keyFn(now)
        if let lastIdx = points.firstIndex(where: { keyFn($0.date) == currentKey }) {
            points[lastIdx] = TrendPoint(date: now, value: currentValue)
        } else {
            points.append(TrendPoint(date: now, value: currentValue))
        }

        return points
    }

    /// 将日期归到 bucket 的 key 上(每个 bucket 唯一)。
    private static func bucketKey(_ d: Date, bucket: TrendRange.Bucket, calendar cal: Calendar) -> Date {
        switch bucket {
        case .day:
            return cal.startOfDay(for: d)
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            return cal.date(from: comps) ?? d
        case .month:
            let comps = cal.dateComponents([.year, .month], from: d)
            return cal.date(from: comps) ?? d
        }
    }
}
