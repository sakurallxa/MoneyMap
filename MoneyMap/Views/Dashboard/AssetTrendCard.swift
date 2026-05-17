import SwiftUI
import Charts

/// "总资产走势"卡 — 标题 / 区间涨跌 / 末值 / 中文 RangeTabs / 折线 / X 轴时间 hints
struct AssetTrendCard: View {
    let snapshots: [DailySnapshot]
    @Binding var range: TrendRange
    var hideBalance: Bool = false

    private var filtered: [DailySnapshot] {
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard let start = range.startDate else { return sorted }
        return sorted.filter { $0.date >= start }
    }

    private var delta: Double {
        guard let f = filtered.first, let l = filtered.last else { return 0 }
        return l.totalValueCNY - f.totalValueCNY
    }

    private var pct: Double {
        guard let f = filtered.first, let l = filtered.last, f.totalValueCNY > 0 else { return 0 }
        return (l.totalValueCNY - f.totalValueCNY) / f.totalValueCNY * 100
    }

    private var endValue: Double {
        filtered.last?.totalValueCNY ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 第一行:标题 + 区间涨跌
            HStack {
                Text("总资产走势")
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.2)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(hideBalance ? "¥····" : (delta >= 0 ? "+" : "-") + "¥\(formatNumber(abs(delta)))" + String(format: " · %+.2f%%", pct))
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.pnlColor(delta))
            }

            // 第二行:大数字(区间末值 = 当前总资产)
            Text(hideBalance ? "¥· · · · ·" : "¥\(formatNumber(endValue))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .kerning(-0.5)
                .monospacedDigit()
                .foregroundStyle(.primary)

            // 第三行:中文 RangeTabs
            RangeTabsView(range: $range, dark: false)

            // 第四行:折线图
            if filtered.count >= 2 {
                chart
            } else {
                Text("数据不足")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }

            // 第五行:X 轴时间 hints
            if filtered.count >= 2 {
                axisHints
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

    @ViewBuilder
    private var chart: some View {
        Chart(filtered) { snap in
            LineMark(
                x: .value("日期", snap.date),
                y: .value("总资产", snap.totalValueCNY)
            )
            .foregroundStyle(Theme.Palette.accent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))

            AreaMark(
                x: .value("日期", snap.date),
                y: .value("总资产", snap.totalValueCNY)
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

    private var axisHints: some View {
        HStack {
            if let first = filtered.first {
                Text(formatAxisDate(first.date))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if filtered.count > 4,
               let mid = filtered[safe: filtered.count / 2] {
                Text(formatAxisDate(mid.date))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            Text("今天")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
    }

    private func formatAxisDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        switch range {
        case .day, .week: f.dateFormat = "M月d日"
        case .month: f.dateFormat = "M月d日"
        case .ytd: f.dateFormat = "M月"
        case .all: f.dateFormat = "yyyy年"
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

extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
