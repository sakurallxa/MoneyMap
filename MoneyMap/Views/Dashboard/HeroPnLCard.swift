import SwiftUI

/// 黑金 Hero · 财富快照卡。
/// 信息层级:
///   eyebrow:● 财富快照 · 投资以来 X 起
///   主数字:总资产 50pt
///   2 格 metric:左 = 累计盈亏 + 累计%;右 = 年化收益率
struct HeroPnLCard: View {
    let totalAssetsCNY: Double
    let totalPnL: Double
    let totalPnLPct: Double
    let annualizedPct: Double
    let earliestDate: Date?
    let lastRefreshLabel: String
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

            VStack(alignment: .leading, spacing: 18) {
                topRow
                heroNumber
                Divider().overlay(Color.white.opacity(0.10))
                metricGrid
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 14)
    }

    // MARK: - eyebrow

    private var topRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(redOrGreen)
                    .frame(width: 6, height: 6)
                Text("总资产")
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

    // MARK: - 大数字:总资产

    private var heroNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("¥")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(hideBalance ? "· · · · ·" : formatNumber(totalAssetsCNY))
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .kerning(-2)
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .accessibilityLabel(totalAssetsCNY.accessibilityAmountLabel(prefix: "总资产", hidden: hideBalance))
    }

    // MARK: - 2 格 metric

    private var metricGrid: some View {
        HStack(spacing: 12) {
            cumulativePnLCell
            annualizedCell
        }
    }

    /// 左格 · 累计盈亏 + 累计收益率
    private var cumulativePnLCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("累计盈亏")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(isUp ? "+¥" : "-¥")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(redOrGreen)
                Text(hideBalance ? "· · · ·" : formatNumber(abs(totalPnL)))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .kerning(-0.5)
                    .foregroundStyle(redOrGreen)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(hideBalance ? "··%" : String(format: "%+.2f%%", totalPnLPct))
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(redOrGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hideBalance
            ? "累计盈亏 已隐藏"
            : "累计盈亏 \(totalPnL.accessibilityAmountLabel(prefix: isUp ? "盈利" : "亏损")) · \(totalPnLPct.accessibilityPercentLabel())")
    }

    /// 右格 · 年化收益率
    private var annualizedCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("年化收益率")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))

            Text(hideBalance ? "··%" : String(format: "%+.2f%%", annualizedPct))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .kerning(-0.5)
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // 空占位,保证左右两格高度一致
            Text(" ")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .opacity(0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hideBalance
            ? "年化收益率 已隐藏"
            : "年化收益率 \(annualizedPct.accessibilityPercentLabel())")
    }

    // MARK: - helpers

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
