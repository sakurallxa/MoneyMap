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

    /// 新用户空态判定:无任何账户且无任何持仓
    private var isEmptyNewUser: Bool {
        accounts.isEmpty && positions.isEmpty
    }

    var body: some View {
        NavigationStack {
            if isEmptyNewUser {
                DashboardEmptyV2(
                    nickname: userNickname,
                    onAddAccount: {
                        NotificationCenter.default.post(name: .switchToTab, object: 1)
                    },
                    hideBalance: $hideBalance,
                    onRefresh: { Task { await refresh() } },
                    isRefreshing: isRefreshing
                )
                .refreshable { await refresh() }
            } else {
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
                            hasTargets: !targets.isEmpty,
                            hideBalance: hideBalance
                        )

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
                .navigationBarHidden(true)
                .refreshable { await refresh() }
            }
        }
    }

    /// 顶部:钱袋 + 问候 + 隐藏余额。刷新统一交给下拉手势(P2-019:去掉重复刷新按钮)。
    private var headerRow: some View {
        PageHeader(title: "钱袋", subtitle: greeting) {
            HideBalanceToggle()
        }
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
        // 与启动序列对齐:刷价 → 确认在途 DCA → 写今日快照 → 推 Widget
        await PriceRefreshService.refreshAll(context: context)
        await DCAService.confirmRipePending(context: context)
        SnapshotService.recordToday(context: context)
        WidgetState.push(context: context)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        lastRefreshLabel = f.string(from: Date())
        isRefreshing = false
    }

}

/// 复用的交易行 — 紧凑版,用在 Dashboard 和 Transactions tab
struct TransactionRow: View {
    let tx: TransactionRecord
    var hideAmount: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: iconName, color: iconBg, size: .md)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tx.type.displayName)
                        .font(Theme.serif(15, weight: .semibold))
                    // P1-015 + P1-016:合并三态为两态显示,在途用统一 StatusPill
                    if tx.status == .pending {
                        StatusPill(text: "在途", tone: .pending)
                    }
                }
                Text(subtitleText)
                    .font(Theme.serif(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(hideAmount ? kHiddenAmountMask : amountText)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                Text(timeText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: tx.tradeDate)
    }

    /// P1-012:交易类型图标按三族重新归位,颜色严格遵循 PnL 方向语义
    /// - **持仓变动 · 对角箭头族**:加仓/卖出/定投 — 钱与持仓同时反向流动
    /// - **现金流 · 垂直箭头族**:入金/出金 — 现金单边进出
    /// - **现金事件 · 专属符号**:分红(gift)、转账(arrow.left.arrow.right)
    private var iconName: String {
        switch tx.type {
        // 持仓变动 — 对角线箭头族
        case .buyFund, .buyStock: return "arrow.down.left"           // 资产进入
        case .sellFund, .sellStock: return "arrow.up.right"          // 资产卖出
        case .dcaDeduct, .dcaConfirm: return "arrow.down.left.circle" // 定投扣款 = 进入(带环表明自动)
        // 现金流 — 垂直箭头族
        case .deposit: return "arrow.down.to.line"
        case .withdraw: return "arrow.up.to.line"
        // 现金事件 — 专属符号
        case .dividend: return "gift.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    /// 颜色按"钱/持仓方向"统一:增加 = pnlUp(红),减少 = pnlDown(绿),中性 = 铜
    private var iconBg: Color {
        switch tx.type {
        // 持仓增加 / 现金减少 — 红
        case .buyFund, .buyStock, .dcaDeduct, .dcaConfirm:
            return Theme.Palette.pnlUp
        // 持仓减少 / 现金增加 — 绿
        case .sellFund, .sellStock:
            return Theme.Palette.pnlDown
        // 现金增加 — 红
        case .deposit, .dividend:
            return Theme.Palette.pnlUp
        // 现金减少 — 绿
        case .withdraw:
            return Theme.Palette.pnlDown
        // 中性 — 铜
        case .transfer:
            return Theme.Bronze.dark
        }
    }

    private var subtitleText: String {
        let base: String
        switch tx.type {
        case .transfer:
            base = "\(tx.fromAccountName) → \(tx.toAccountName)"
        case .dividend:
            base = !tx.assetName.isEmpty ? "\(tx.assetName) · \(tx.assetCode)" : tx.toAccountName
        case .deposit, .withdraw:
            base = tx.toAccountName.isEmpty ? tx.fromAccountName : tx.toAccountName
        default:
            base = !tx.assetName.isEmpty ? "\(tx.assetName) · \(tx.assetCode)" : tx.toAccountName
        }
        // 手续费 > 0 时附加显示
        if tx.fee > 0 {
            return base + " · 含费 ¥\(String(format: "%.2f", tx.fee))"
        }
        return base
    }

    private var amountText: String {
        // 展示净现金流(含手续费) — 用户在 row 上看到的就是实际进出账户的金额
        let signed = tx.netSignedCashAmount
        if signed == 0 {
            return CurrencyFormatter.cnyString(tx.amount)
        }
        return CurrencyFormatter.signedCNY(signed)
    }

    private var amountColor: Color {
        Color.pnlColor(tx.netSignedCashAmount)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self, TargetAllocation.self], inMemory: true)
}
