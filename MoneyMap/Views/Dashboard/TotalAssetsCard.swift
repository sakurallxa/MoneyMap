import SwiftUI

/// "总资产"卡 — 一张白卡,左侧文字 stack,右侧 30 天 sparkline。
struct TotalAssetsCard: View {
    let totalCNY: Double
    let todayDelta: Double
    let todayPct: Double
    let sparkline30d: [Double]
    var hideBalance: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("总资产")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(hideBalance ? "¥· · · · ·" : "¥\(formatNumber(totalCNY))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .kerning(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .accessibilityLabel(totalCNY.accessibilityAmountLabel(prefix: "总资产", hidden: hideBalance))

                HStack(spacing: 4) {
                    Image(systemName: todayDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(hideBalance ? "¥····" : (todayDelta >= 0 ? "+" : "-") + "¥\(formatNumber(abs(todayDelta)))")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                    Text(hideBalance ? "··%" : String(format: " · %+.2f%%", todayPct))
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.pnlColor(todayDelta))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hideBalance
                    ? "今日盈亏 已隐藏"
                    : "今日 \(todayDelta.accessibilityAmountLabel(prefix: todayDelta >= 0 ? "盈利" : "亏损")) · \(todayPct.accessibilityPercentLabel())")

                Text("今日")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if sparkline30d.count >= 2 {
                MiniSparkline(
                    values: sparkline30d,
                    lineColor: Theme.Palette.accent.opacity(0.55),
                    fillGradient: Gradient(stops: [
                        .init(color: Theme.Palette.accent.opacity(0.20), location: 0),
                        .init(color: Theme.Palette.accent.opacity(0), location: 1)
                    ]),
                    lineWidth: 1.8
                )
                .frame(width: 92, height: 56)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}
