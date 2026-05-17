import SwiftUI
import SwiftData

struct RebalanceView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var positions: [Position]
    @Query(filter: #Predicate<TransactionRecord> { $0.statusRaw == "PENDING" })
    private var pendingTxs: [TransactionRecord]
    @Query private var rates: [ExchangeRate]
    @Query(sort: \TargetAllocation.assetClassRaw) private var targets: [TargetAllocation]

    @AppStorage("rebalanceModelRaw") private var modelRaw: String = RebalanceModel.balanced.rawValue
    @AppStorage("lastRebalanceDate") private var lastRebalanceTimestamp: Double = 0
    @AppStorage("hideBalance") private var hideBalance = false

    @State private var showEditSheet = false
    @State private var prefill: RebalancePrefill?

    private let tolerance: Double = 3.0  // 容差 ±3%

    private var currentModel: RebalanceModel {
        RebalanceModel(rawValue: modelRaw) ?? .balanced
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var breakdown: AssetBreakdown {
        ValuationService.currentBreakdown(
            accounts: accounts, positions: positions,
            pendingTransactions: pendingTxs, rates: rateMap
        )
    }

    private var items: [RebalanceItem] {
        RebalanceService.compute(breakdown: breakdown, targets: targets)
    }

    private var overallDeviation: Double {
        RebalanceService.overallDeviation(items: items)
    }

    private var statusText: String {
        let d = overallDeviation
        if d < 2 { return "组合非常匹配目标,无需调整" }
        if d < 5 { return "轻微偏离,可暂不调整" }
        if d < 10 { return "建议适度调整" }
        return "偏离较大,建议尽快再平衡"
    }

    private var statusColor: Color {
        let d = overallDeviation
        if d < 2 { return .pnlNegative }
        if d < 5 { return .secondary }
        if d < 10 { return .orange }
        return .pnlPositive
    }

    private var daysSinceLast: Int? {
        guard lastRebalanceTimestamp > 0 else { return nil }
        let last = Date(timeIntervalSince1970: lastRebalanceTimestamp)
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }

    private var sellItems: [RebalanceItem] {
        items.filter { $0.action == .sell }.sorted { abs($0.deviationPercent) > abs($1.deviationPercent) }
    }

    private var buyItems: [RebalanceItem] {
        items.filter { $0.action == .buy }.sorted { abs($0.deviationPercent) > abs($1.deviationPercent) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if targets.isEmpty {
                    emptyState
                } else {
                    summaryHero
                    comparisonCard
                    suggestionsCard
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
        .navigationTitle("再平衡")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !targets.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) { TargetAllocationSheet() }
        .sheet(item: $prefill) { p in AddTransactionSheet(prefill: p) }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "scalemass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("还没设置目标配置")
                .font(.headline)
            Text("设置每类资产的目标比例,系统会告诉你需要买入或卖出多少来匹配你的目标")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                showEditSheet = true
            } label: {
                Text("现在设置")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 整体偏离度 hero

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("整体偏离度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 10, weight: .semibold))
                    Text(currentModel.displayName + "型")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", overallDeviation))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .kerning(-1)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("整体偏离度 \(String(format: "%.1f", overallDeviation)) 个百分点")
            Text(statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
            if let days = daysSinceLast {
                Text("上次再平衡 \(days) 天前")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    // MARK: - 当前 vs 目标卡

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前 vs 目标")
                .font(.system(size: 17, weight: .bold))

            VStack(spacing: 18) {
                ForEach(items) { item in
                    comparisonRow(item)
                }
            }

            // 底部 legend
            HStack(spacing: 14) {
                legendItem(label: "当前", isDot: true)
                legendItem(label: "目标", isDot: false, lineOnly: true)
                legendItem(label: "容差", isDot: false, dashed: true)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func comparisonRow(_ item: RebalanceItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顶行: 色点 + 类名 + 偏差胶囊
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: item.assetClass.hexColor))
                        .frame(width: 9, height: 9)
                    Text(item.assetClass.displayName)
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                deviationBadge(item)
            }

            // 金额行
            HStack(spacing: 4) {
                Text("当前 \(hideBalance ? kHiddenAmountMask : "¥\(formatShort(item.currentValue)) ")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text("目标 \(hideBalance ? kHiddenAmountMask : "¥\(formatShort(item.targetValue))")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 进度 bar(目标范围带 + 目标线 + 当前圆点)
            progressBar(item)
                .padding(.vertical, 4)

            // 底行
            HStack {
                Text(String(format: "当前 %.1f%% · 目标 %.0f%% · 容差 ±%.0f%%",
                            item.currentPercent, item.targetPercent, tolerance))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private func deviationBadge(_ item: RebalanceItem) -> some View {
        let dev = item.deviationPercent
        let within = abs(dev) <= tolerance
        return HStack(spacing: 3) {
            Image(systemName: within ? "checkmark.circle.fill" : (dev > 0 ? "arrow.up" : "arrow.down"))
                .font(.system(size: 9, weight: .bold))
            Text(within ? "合格" : String(format: "%+.1f%%", dev))
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(within ? Color.pnlNegative : Color.pnlPositive)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((within ? Color.pnlNegative : Color.pnlPositive).opacity(0.12))
        .clipShape(Capsule())
    }

    private func progressBar(_ item: RebalanceItem) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 22
            let target = item.targetPercent / 100
            let current = item.currentPercent / 100
            let tolMin = max(0, target - tolerance / 100)
            let tolMax = min(1, target + tolerance / 100)
            let bandX = w * tolMin
            let bandW = w * (tolMax - tolMin)
            let targetX = w * target
            let currentX = w * min(1, current)

            ZStack(alignment: .leading) {
                // 8pt 轨道
                Capsule()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 8)
                    .offset(y: (h - 8) / 2)

                // 16pt 高目标范围带(虚线)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color(hex: item.assetClass.hexColor).opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: item.assetClass.hexColor).opacity(0.10))
                    )
                    .frame(width: bandW, height: 16)
                    .offset(x: bandX, y: (h - 16) / 2)

                // 目标线 (2pt × 20pt)
                Rectangle()
                    .fill(Color(hex: item.assetClass.hexColor))
                    .frame(width: 2, height: 20)
                    .offset(x: targetX - 1, y: (h - 20) / 2)

                // 当前圆点 12pt(白底 3pt 边)
                ZStack {
                    Circle()
                        .fill(Color(hex: item.assetClass.hexColor))
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 3)
                }
                .frame(width: 12, height: 12)
                .offset(x: max(0, min(w - 12, currentX - 6)), y: (h - 12) / 2)
            }
            .frame(height: h)
        }
        .frame(height: 22)
    }

    private func legendItem(label: String, isDot: Bool, lineOnly: Bool = false, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            ZStack {
                if isDot {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 9, height: 9)
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 2)
                        .frame(width: 9, height: 9)
                } else if lineOnly {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: 11)
                } else if dashed {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [2, 1.5]))
                        .frame(width: 14, height: 7)
                }
            }
            .frame(width: 16, height: 14)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 调整建议卡

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("调整建议")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text("\(sellItems.count + buyItems.count) 项 · 按偏差排序")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if sellItems.isEmpty && buyItems.isEmpty {
                Text("无需调整 · 当前组合在目标范围内 👍")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                if !sellItems.isEmpty {
                    groupHeader("卖出")
                    VStack(spacing: 0) {
                        ForEach(Array(sellItems.enumerated()), id: \.element.id) { idx, item in
                            suggestionRow(item)
                            if idx < sellItems.count - 1 {
                                Divider().opacity(0.4).padding(.leading, 50)
                            }
                        }
                    }
                }
                if !buyItems.isEmpty {
                    groupHeader("买入").padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(Array(buyItems.enumerated()), id: \.element.id) { idx, item in
                            suggestionRow(item)
                            if idx < buyItems.count - 1 {
                                Divider().opacity(0.4).padding(.leading, 50)
                            }
                        }
                    }
                }
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

    private func groupHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
    }

    private func suggestionRow(_ item: RebalanceItem) -> some View {
        let isBuy = item.action == .buy
        let color: Color = isBuy ? .pnlPositive : .pnlNegative
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                Image(systemName: isBuy ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(isBuy ? "买入" : "卖出") · \(item.assetClass.displayName)")
                    .font(.system(size: 14, weight: .semibold))
                Text(String(format: "%.1f%% → %.0f%%", item.currentPercent, item.targetPercent))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(hideBalance ? kHiddenAmountMask : "¥" + formatShort(abs(item.actionAmount)))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(String(format: "%+.1f%%", item.deviationPercent))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Button {
                prefill = RebalancePrefill(
                    action: isBuy ? .buy : .sell,
                    assetClass: item.assetClass,
                    amount: abs(item.actionAmount)
                )
            } label: {
                Text("去交易")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private func formatShort(_ v: Double) -> String {
        let absV = abs(v)
        if absV >= 10_000 {
            return String(format: "%.2f万", v / 10_000)
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}
