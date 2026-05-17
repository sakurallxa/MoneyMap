import SwiftUI

/// "资产分布"卡 — 标题 + 「再平衡 ›」入口 + 偏离目标行 + donut + top 4 ranked list
struct BreakdownDonutCard: View {
    let breakdown: AssetBreakdown
    let deviationPercent: Double
    var hideBalance: Bool = false

    private var segments: [DonutChart.DonutSegment] {
        breakdown.segments.map {
            DonutChart.DonutSegment(id: $0.label, value: $0.value, color: Color(hex: $0.colorHex))
        }
    }

    private var rankedSegments: [(label: String, value: Double, colorHex: String)] {
        breakdown.segments.sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("资产分布")
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.2)
                Spacer()
                NavigationLink {
                    RebalanceView()
                } label: {
                    HStack(spacing: 3) {
                        Text("再平衡")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Palette.accentDark)
                }
                .buttonStyle(.plain)
            }

            // 偏离目标行
            HStack(spacing: 4) {
                Text("偏离目标")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", deviationPercent))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(deviationPercent < 5 ? .secondary : Color.pnlPositive)
                Text("· \(deviationLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 主体:左 donut + 右 ranked list
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    DonutChart(segments: segments, thickness: 16, gapDegrees: 1.5)
                        .frame(width: 124, height: 124)
                    VStack(spacing: 2) {
                        Text("共 \(rankedSegments.count) 类")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.3)
                            .foregroundStyle(.tertiary)
                        Text(hideBalance ? "¥····" : "¥\(formatShort(breakdown.total))")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(-0.3)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rankedSegments.indices, id: \.self) { i in
                        let s = rankedSegments[i]
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: s.colorHex))
                                .frame(width: 7, height: 7)
                            Text(s.label)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text(percentString(s.value))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
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

    private var deviationLabel: String {
        if deviationPercent < 2 { return "几乎匹配" }
        if deviationPercent < 5 { return "轻微偏离" }
        if deviationPercent < 10 { return "明显偏离" }
        return "严重偏离"
    }

    private func percentString(_ value: Double) -> String {
        guard breakdown.total > 0 else { return "0%" }
        return String(format: "%.1f%%", value / breakdown.total * 100)
    }

    private func formatShort(_ v: Double) -> String {
        let abs = abs(v)
        if abs >= 100_000_000 {
            return String(format: "%.2f亿", v / 100_000_000)
        }
        if abs >= 10_000 {
            return String(format: "%.1fk", v / 1_000)
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}
