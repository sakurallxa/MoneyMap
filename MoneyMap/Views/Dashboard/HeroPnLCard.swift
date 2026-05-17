import SwiftUI

/// 黑金 Hero · 累计盈亏卡片。
/// 包含: eyebrow + "投资以来"提示 / 50pt 主数字 / 涨跌 pill + 年化 / sparkline / range tabs / 本期变化行
struct HeroPnLCard: View {
    let totalPnL: Double
    let totalPnLPct: Double
    let annualizedPct: Double
    let earliestDate: Date?
    let lastRefreshLabel: String
    let sparklineValues: [Double]
    let periodChange: Double
    @Binding var range: TrendRange
    var hideBalance: Bool = false

    private var isUp: Bool { totalPnL >= 0 }
    private var redOrGreen: Color {
        isUp ? Theme.Palette.heroAccentRed : Theme.Palette.heroAccentGreen
    }

    var body: some View {
        ZStack {
            // 渐变底
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.heroBlackGoldGradient)

            // 金色径向光晕(右上)
            RadialGradient(
                colors: [Color(red: 200/255, green: 149/255, blue: 109/255, opacity: 0.28),
                         Color.clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 200
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            // hairline 高光描边
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .inset(by: 0.25)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

            VStack(alignment: .leading, spacing: 16) {
                topRow
                bigNumber
                metaRow
                sparkline
                RangeTabsView(range: $range, dark: true)
                Divider().overlay(Color.white.opacity(0.08))
                periodChangeRow
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 14)
    }

    private var topRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(redOrGreen)
                    .frame(width: 6, height: 6)
                Text("累计盈亏")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.6)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Spacer()
            Text(refreshLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(isUp ? "+¥" : "-¥")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(hideBalance ? "· · · · ·" : formatNumber(abs(totalPnL)))
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .kerning(-2)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var metaRow: some View {
        HStack {
            HStack(spacing: 3) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                Text(hideBalance ? "··%" : String(format: "%+.2f%%", totalPnLPct))
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(redOrGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(redOrGreen.opacity(0.20))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(redOrGreen.opacity(0.35), lineWidth: 0.5))

            Spacer()

            HStack(spacing: 4) {
                Text("年化")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.55))
                Text(hideBalance ? "··%" : String(format: "%+.2f%%", annualizedPct))
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var sparkline: some View {
        if sparklineValues.count >= 2 {
            MiniSparkline(
                values: sparklineValues,
                lineColor: redOrGreen,
                fillGradient: Gradient(stops: [
                    .init(color: redOrGreen.opacity(0.28), location: 0),
                    .init(color: redOrGreen.opacity(0), location: 1)
                ]),
                lineWidth: 2.2,
                showEndDot: true,
                glow: true
            )
            .frame(height: 78)
        } else {
            Color.clear.frame(height: 78)
        }
    }

    private var periodChangeRow: some View {
        HStack {
            Text("\(range.changeLabelPrefix)变化")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
            let positive = periodChange >= 0
            let c: Color = positive ? Theme.Palette.heroAccentRed : Theme.Palette.heroAccentGreen
            Text(hideBalance ? "¥· · · · ·" : (positive ? "+" : "-") + "¥\(formatNumber(abs(periodChange)))")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(c)
        }
    }

    private var refreshLabel: String {
        if let earliestDate = earliestDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "yyyy.MM"
            return "投资以来 · \(f.string(from: earliestDate)) 起"
        }
        if !lastRefreshLabel.isEmpty {
            return "刚刚更新 \(lastRefreshLabel)"
        }
        return ""
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}
