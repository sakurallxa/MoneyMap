import SwiftUI

/// 黑金 Centurion 风 · 财富快照卡。
/// 信息层级:
///   eyebrow:● 总资产 · TOTAL  |  投资以来 · YYYY.MM 起
///   金箔 hairline
///   主数字:¥ + 米→金 gradient 数字
///   金菱形分隔符
///   2 格 metric:左 = 累计盈亏 + 累计%;右 = 年化收益率(CAGR,首笔交易至今)
struct HeroPnLCard: View {
    let totalAssetsCNY: Double
    let totalPnL: Double
    let totalPnLPct: Double
    let annualizedPct: Double
    let earliestDate: Date?
    let lastRefreshLabel: String
    var hideBalance: Bool = false

    private var isUp: Bool { totalPnL >= 0 }

    /// 统一红色:累计盈亏与年化收益率共用同一暖红
    private var accentRed: Color { Theme.Palette.heroAccentRed }

    /// 米色 → 浅金 → 深金 渐变(用于 ¥ 与主数字)
    // 转发到 Theme.Bronze.* — 三张 dashboard 卡共享同一套金箔渐变(P0-Composition)
    private var creamGoldGradient: LinearGradient { Theme.Bronze.creamGoldGradient }
    private var goldHairlineGradient: LinearGradient { Theme.Bronze.goldHairline }

    var body: some View {
        ZStack {
            // 渐变底
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.heroBlackGoldGradient)

            // guilloché 同心环底纹(钞票雕刻感)
            guillochePattern
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)

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
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)

            VStack(alignment: .leading, spacing: 14) {
                topRow

                // 金箔细横线
                Rectangle()
                    .fill(goldHairlineGradient)
                    .frame(height: 0.6)

                heroNumber

                // 金菱形分隔符
                diamondDivider

                metricGrid
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 14)
    }

    // MARK: - guilloché 同心环

    private var guillochePattern: some View {
        Canvas { context, size in
            let ringColor = Color(red: 200/255, green: 149/255, blue: 109/255, opacity: 0.085)
            let innerColor = Color(red: 251/255, green: 239/255, blue: 210/255, opacity: 0.05)

            // 4 个错位圆心,模拟纸币 guilloché 重叠环
            let centers: [CGPoint] = [
                CGPoint(x: size.width * 0.12, y: size.height * 0.52),
                CGPoint(x: size.width * 0.36, y: size.height * 0.48),
                CGPoint(x: size.width * 0.60, y: size.height * 0.52),
                CGPoint(x: size.width * 0.84, y: size.height * 0.48),
                CGPoint(x: size.width * 1.05, y: size.height * 0.52)
            ]

            for center in centers {
                for i in 0..<16 {
                    let radius = 10 + CGFloat(i) * 6.5
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let path = Path(ellipseIn: rect)
                    context.stroke(
                        path,
                        with: .color(i.isMultiple(of: 2) ? ringColor : innerColor),
                        lineWidth: 0.45
                    )
                }
            }
        }
    }

    // MARK: - eyebrow

    private var topRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(creamGoldGradient)
                    .frame(width: 6, height: 6)
                Text("总资产 · TOTAL")
                    .font(Theme.TypeToken.eyebrow())
                    .kerning(Theme.TypeToken.eyebrowKerning)
                    .foregroundStyle(Color.white.opacity(0.82))
            }
            Spacer()
            Text(refreshLabel)
                .font(Theme.serif(11))
                .kerning(0.4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    // MARK: - 大数字:总资产(米→金 gradient)

    private var heroNumber: some View {
        MoneyText(
            value: totalAssetsCNY,
            scale: .hero,
            hidden: hideBalance,
            style: AnyShapeStyle(creamGoldGradient),
            minimumScaleFactor: 0.55
        )
        .shadow(color: Color(hex: "#C8956D").opacity(0.18), radius: 8, x: 0, y: 2)
        .accessibilityLabel(totalAssetsCNY.accessibilityAmountLabel(prefix: "总资产", hidden: hideBalance))
    }

    // MARK: - 金菱形分隔符

    private var diamondDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(goldHairlineGradient)
                .frame(height: 0.6)

            Rectangle()
                .fill(creamGoldGradient)
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
                .shadow(color: Color(hex: "#C8956D").opacity(0.6), radius: 3, x: 0, y: 0)

            Rectangle()
                .fill(goldHairlineGradient)
                .frame(height: 0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    // MARK: - 2 格 metric

    private var metricGrid: some View {
        HStack(spacing: 12) {
            cumulativePnLCell
            annualizedCell
        }
    }

    /// 玻璃 inset 质感背景
    private var glassCellBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))

            // 顶部内嵌高光
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )

            // 底部金色微反光
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color(hex: "#C8956D").opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }

    /// 左格 · 累计盈亏 + 累计收益率(P2-021:正负使用红/绿)
    private var cumulativePnLCell: some View {
        let cellColor: Color = isUp
            ? Theme.Palette.heroAccentRed
            : Theme.Palette.heroAccentGreen
        return VStack(alignment: .leading, spacing: 6) {
            Text("累计盈亏")
                .font(Theme.TypeToken.label(11))
                .foregroundStyle(Color.white.opacity(0.6))

            MoneyText(
                value: totalPnL,
                scale: .metric,
                signed: true,
                hidden: hideBalance,
                color: cellColor
            )

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(isUp ? "+" : "−")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(cellColor.opacity(0.85))
                Text(hideBalance ? "··" : String(format: "%.2f", abs(totalPnLPct)))
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(cellColor)
                Text("%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cellColor.opacity(0.75))
                    .baselineOffset(0.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCellBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hideBalance
            ? "累计盈亏 已隐藏"
            : "累计盈亏 \(totalPnL.accessibilityAmountLabel(prefix: isUp ? "盈利" : "亏损")) · \(totalPnLPct.accessibilityPercentLabel())")
    }

    /// 距离首笔交易过去的天数(nil 代表完全没交易)。
    private var daysSinceFirstTx: Int? {
        guard let earliestDate else { return nil }
        return Calendar.current.dateComponents([.day], from: earliestDate, to: Date()).day
    }

    /// 不足 30 天的累计百分比"年化"在数学上没意义(过度复利炸天),
    /// 因此 30 天以内只显示"暂不足"占位,不秀任何数字 —
    /// 既诚实(不假装算得出年化)又是个友好的"再用一个月会看到的"暗示。
    private var hasEnoughDataForAnnualized: Bool {
        (daysSinceFirstTx ?? 0) >= 30
    }

    /// 右格 · 年化收益率(标题恒定)。三态:
    /// - 无交易 → 主数字"—" + 副标"暂无交易记录"
    /// - <30 天 → 主数字"暂不足" + 副标"首笔交易 X 天前 · 需满 30 天"
    /// - ≥30 天 → 主数字 ±X.XX% + 副标"首笔交易 X 天前"
    private var annualizedCell: some View {
        let cellColor: Color = annualizedPct >= 0
            ? Theme.Palette.heroAccentRed
            : Theme.Palette.heroAccentGreen
        let title = "年化收益率"
        let subtitle: String = {
            guard let d = daysSinceFirstTx else { return "暂无交易记录" }
            return hasEnoughDataForAnnualized
                ? "首笔交易 \(d) 天前"
                : "首笔交易 \(d) 天前 · 需满 30 天"
        }()
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.TypeToken.label(11))
                .foregroundStyle(Color.white.opacity(0.6))

            // 主数字区:三态分支
            if daysSinceFirstTx == nil {
                // 无交易
                Text("—")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(height: 26, alignment: .leading)
            } else if !hasEnoughDataForAnnualized {
                // <30 天:占位"暂不足"
                Text("暂不足")
                    .font(.system(size: 17, weight: .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(height: 26, alignment: .leading)
            } else {
                // ≥30 天:正常 CAGR 百分比
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(annualizedPct >= 0 ? "+" : "−")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(cellColor.opacity(0.9))
                    Text(hideBalance ? "··" : String(format: "%.2f", abs(annualizedPct)))
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(cellColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(cellColor.opacity(0.85))
                        .baselineOffset(0.5)
                }
            }

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCellBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if hideBalance { return "\(title) 已隐藏" }
            if daysSinceFirstTx == nil { return "\(title) 暂无交易记录" }
            if !hasEnoughDataForAnnualized { return "\(title) 数据暂不足 \(subtitle)" }
            return "\(title) \(annualizedPct.accessibilityPercentLabel()) · \(subtitle)"
        }())
    }

    // MARK: - helpers

    /// P2-023:让"投资以来"和"刚刚更新"在两者都存在时并列显示。
    private var refreshLabel: String {
        var parts: [String] = []
        if let earliestDate = earliestDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "yyyy.MM"
            parts.append("投资以来 · \(f.string(from: earliestDate))")
        }
        if !lastRefreshLabel.isEmpty {
            parts.append(lastRefreshLabel + " 更新")
        }
        return parts.joined(separator: " · ")
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}
