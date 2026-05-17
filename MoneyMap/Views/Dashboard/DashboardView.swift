import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var positions: [Position]
    @Query(sort: \DailySnapshot.date, order: .forward) private var snapshots: [DailySnapshot]
    @Query(filter: #Predicate<TransactionRecord> { $0.statusRaw == "PENDING" })
    private var pendingTxs: [TransactionRecord]
    @Query(sort: \TransactionRecord.tradeDate, order: .reverse) private var allTxs: [TransactionRecord]
    @Query private var rates: [ExchangeRate]
    @Query(sort: \TargetAllocation.assetClassRaw) private var targets: [TargetAllocation]

    @AppStorage("hideBalance") private var hideBalance = false
    @AppStorage("dashboardAssetRange") private var assetRangeRaw: String = TrendRange.month.rawValue
    @State private var lastRefreshLabel = ""
    @State private var isRefreshing = false

    private var assetRange: TrendRange {
        get { TrendRange(rawValue: assetRangeRaw) ?? .month }
    }

    private var assetRangeBinding: Binding<TrendRange> {
        Binding(get: { TrendRange(rawValue: assetRangeRaw) ?? .month },
                set: { assetRangeRaw = $0.rawValue })
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var breakdown: AssetBreakdown {
        ValuationService.currentBreakdown(
            accounts: accounts,
            positions: positions,
            pendingTransactions: pendingTxs,
            rates: rateMap
        )
    }

    /// 累计盈亏:所有持仓的浮盈合计(以 CNY 折算)
    private var totalPnL: Double {
        positions.reduce(0.0) { sum, p in
            sum + p.unrealizedPnL * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
    }

    /// 累计盈亏百分比 = 总浮盈 / 总成本
    private var totalPnLPct: Double {
        let cost = positions.reduce(0.0) { sum, p in
            sum + p.totalCost * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
        guard cost > 0 else { return 0 }
        return totalPnL / cost * 100
    }

    /// 投资以来的最早日期(取最早交易)
    private var earliestTxDate: Date? {
        allTxs.min(by: { $0.tradeDate < $1.tradeDate })?.tradeDate
    }

    /// 反推年化收益率 — 数据不足 30 天时直接显示累计百分比,避免短期复利溢出
    private var annualizedPct: Double {
        guard let earliest = earliestTxDate else { return 0 }
        let cal = Calendar.current
        let daysElapsed = cal.dateComponents([.day], from: earliest, to: Date()).day ?? 1
        let years = Double(daysElapsed) / 365.0
        guard years >= 30.0 / 365.0 else {
            // 不足 30 天 — 不年化,直接返回累计百分比
            return totalPnLPct
        }
        let m = 1 + totalPnLPct / 100
        guard m > 0 else { return 0 }
        return (pow(m, 1 / years) - 1) * 100
    }

    /// 今日盈亏(基于持仓昨收价 vs 实时价 × shares × fx)。
    private var todayChange: (delta: Double, pct: Double) {
        let rmap = rateMap
        var current = 0.0
        var prev = 0.0
        for pos in positions {
            let fx = rmap[pos.effectiveCurrency.rawValue] ?? 1.0
            current += pos.shares * pos.lastPrice * fx
            prev += pos.shares * pos.prevClosePrice * fx
        }
        let delta = current - prev
        let cash = accounts.reduce(0.0) { sum, acc in
            sum + acc.cashBalance * (rmap[acc.currency.rawValue] ?? 1.0)
        }
        let base = prev + cash
        let pct = base > 0 ? delta / base * 100 : 0
        return (delta, pct)
    }

    /// 整体偏离度(从 RebalanceService 拿)
    private var overallDeviation: Double {
        let items = RebalanceService.compute(breakdown: breakdown, targets: targets)
        return RebalanceService.overallDeviation(items: items)
    }

    private var recentTxs: [TransactionRecord] {
        Array(allTxs.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerRow

                    HeroPnLCard(
                        totalAssetsCNY: breakdown.total,
                        totalPnL: totalPnL,
                        totalPnLPct: totalPnLPct,
                        annualizedPct: annualizedPct,
                        earliestDate: earliestTxDate,
                        lastRefreshLabel: lastRefreshLabel,
                        hideBalance: hideBalance
                    )

                    AssetTrendCard(
                        snapshots: snapshots,
                        totalAssetsCNY: breakdown.total,
                        todayDelta: todayChange.delta,
                        todayPct: todayChange.pct,
                        range: assetRangeBinding,
                        hideBalance: hideBalance
                    )

                    BreakdownDonutCard(
                        breakdown: breakdown,
                        deviationPercent: overallDeviation,
                        hideBalance: hideBalance
                    )

                    recentTransactionsCard

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                await refresh()
            }
        }
    }

    /// 顶部:钱袋 + 问候 + 隐藏余额 + 刷新,与 hero 卡片左右对齐。
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("钱袋")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            Text(greeting)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                withAnimation { hideBalance.toggle() }
            } label: {
                Image(systemName: hideBalance ? "eye.slash" : "eye")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("切换余额显示")
            .accessibilityValue(hideBalance ? "已隐藏" : "已显示")
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing
                               ? .linear(duration: 1).repeatForever(autoreverses: false)
                               : .default,
                               value: isRefreshing)
            }
            .disabled(isRefreshing)
        }
        .padding(.horizontal, 4)
    }

    @AppStorage("userNickname") private var userNickname: String = ""

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "早上好"
        case 12..<14: base = "中午好"
        case 14..<18: base = "下午好"
        case 18..<23: base = "晚上好"
        default: base = "夜深了"
        }
        let trimmed = userNickname.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "钱袋用户" {
            return base
        }
        return "\(base),\(trimmed)"
    }

    private func refresh() async {
        isRefreshing = true
        await PriceRefreshService.refreshAll(context: context)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        lastRefreshLabel = f.string(from: Date())
        isRefreshing = false
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近")
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.2)
                Spacer()
                Text("全部 ›")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accentDark)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 4)

            if recentTxs.isEmpty {
                Text("还没有交易记录")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTxs.enumerated()), id: \.element.id) { idx, tx in
                        TransactionRow(tx: tx, hideAmount: hideBalance)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        if idx < recentTxs.count - 1 {
                            Divider().opacity(0.4).padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }
}

/// 复用的交易行 — 紧凑版,用在 Dashboard 和 Transactions tab
struct TransactionRow: View {
    let tx: TransactionRecord
    var hideAmount: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBg.opacity(0.12))
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconBg)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tx.type.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    if tx.status == .pending {
                        PillTag(text: "在途", color: .orange)
                    } else if tx.status == .confirmed {
                        PillTag(text: "已确认", color: .blue)
                    }
                }
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if tx.type == .dcaConfirm {
                    Text(hideAmount ? "+···· 份" : String(format: "+%.2f 份", tx.shares))
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlPositive)
                    Text(hideAmount ? "净值 ¥····" : String(format: "净值 ¥%.4f", tx.price))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(hideAmount ? "¥····" : amountText)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(amountColor)
                    Text(timeText)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: tx.tradeDate)
    }

    private var iconName: String {
        switch tx.type {
        case .dcaDeduct, .dcaConfirm: return "calendar.badge.clock"
        case .buyFund, .buyStock: return "arrow.down.left"
        case .sellFund, .sellStock: return "arrow.up.right"
        case .dividend: return "gift.fill"
        case .transfer: return "arrow.left.arrow.right"
        case .deposit: return "plus"
        case .withdraw: return "minus"
        }
    }

    private var iconBg: Color {
        switch tx.type {
        case .dcaDeduct, .dcaConfirm: return Theme.Palette.accent
        case .buyFund, .buyStock: return .pnlPositive
        case .sellFund, .sellStock: return .pnlNegative
        case .dividend: return .orange
        case .transfer: return Color(hex: "#7B68EE")
        case .deposit: return .pnlNegative
        case .withdraw: return Color(hex: "#8E8E93")
        }
    }

    private var subtitleText: String {
        switch tx.type {
        case .transfer:
            return "\(tx.fromAccountName) → \(tx.toAccountName)"
        case .dividend:
            if !tx.assetName.isEmpty { return "\(tx.assetName) · \(tx.assetCode)" }
            return tx.toAccountName
        case .deposit, .withdraw:
            return tx.toAccountName.isEmpty ? tx.fromAccountName : tx.toAccountName
        default:
            if !tx.assetName.isEmpty { return "\(tx.assetName) · \(tx.assetCode)" }
            return tx.toAccountName
        }
    }

    private var amountText: String {
        let signed = tx.signedAmount
        if signed == 0 {
            return CurrencyFormatter.cnyString(tx.amount)
        }
        return CurrencyFormatter.signedCNY(signed)
    }

    private var amountColor: Color {
        Color.pnlColor(tx.signedAmount)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self, TargetAllocation.self], inMemory: true)
}
