import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var positions: [Position]
    @Query(sort: \DailySnapshot.date, order: .forward) private var snapshots: [DailySnapshot]
    @Query(filter: #Predicate<TransactionRecord> { $0.statusRaw == "PENDING" })
    private var pendingTxs: [TransactionRecord]
    @Query(sort: \TransactionRecord.tradeDate, order: .reverse) private var allTxs: [TransactionRecord]
    @Query private var rates: [ExchangeRate]

    @AppStorage("hideBalance") private var hideBalance = false
    @AppStorage("trendRangeRaw") private var trendRangeRaw: String = TrendRange.month.rawValue
    @State private var isRefreshing = false
    @State private var lastRefreshLabel: String = ""

    private var trendRange: TrendRange {
        TrendRange(rawValue: trendRangeRaw) ?? .month
    }

    /// 按选中粒度聚合后的快照。日:原始日数据;周/月/年:按时间段分组,取每段最后一个快照。
    private var aggregatedSnapshots: [DailySnapshot] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -trendRange.rangeDays, to: Date()) else {
            return snapshots
        }
        let filtered = snapshots.filter { $0.date >= cal.startOfDay(for: cutoff) }

        guard let component = trendRange.groupingComponent else {
            return filtered.sorted { $0.date < $1.date }
        }

        var byPeriod: [Date: DailySnapshot] = [:]
        for snap in filtered {
            guard let interval = cal.dateInterval(of: component, for: snap.date) else { continue }
            let key = interval.start
            if let existing = byPeriod[key], existing.date >= snap.date {
                continue
            }
            byPeriod[key] = snap
        }
        return byPeriod.values.sorted { $0.date < $1.date }
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates {
            m[r.fromCurrency] = r.rate
        }
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
        let base = prev + accountsCashCNY
        let pct = base > 0 ? delta / base * 100 : 0
        return (delta, pct)
    }

    private var accountsCashCNY: Double {
        let rmap = rateMap
        return accounts.reduce(0.0) { sum, acc in
            sum + acc.cashBalance * (rmap[acc.currency.rawValue] ?? 1.0)
        }
    }

    private var recentTxs: [TransactionRecord] {
        Array(allTxs.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroCard
                    quickStats
                    breakdownCard
                    trendCard
                    pendingCard
                    recentTransactionsCard
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("钱袋")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { hideBalance.toggle() }
                    } label: {
                        Image(systemName: hideBalance ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                await refreshPrices()
            }
        }
    }

    private func refreshPrices() async {
        isRefreshing = true
        await PriceRefreshService.refreshAll(context: context)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        lastRefreshLabel = f.string(from: Date())
        isRefreshing = false
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("总资产")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !lastRefreshLabel.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("更新于 \(lastRefreshLabel)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            AmountText(amount: breakdown.total, size: .hero, hidden: hideBalance)
                .foregroundStyle(.primary)

            HStack(alignment: .center) {
                Text("今日")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: todayChange.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.footnote.weight(.bold))
                        Text(hideBalance ? "¥****" : CurrencyFormatter.signedCNY(todayChange.delta))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(hideBalance ? "**%" : CurrencyFormatter.percent(todayChange.pct))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.pnlColor(todayChange.delta))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardStyle()
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            MetricTile(
                label: "账户数",
                value: "\(accounts.count)",
                valueColor: .primary
            )
            MetricTile(
                label: "持仓数",
                value: "\(positions.count)",
                valueColor: .primary
            )
            MetricTile(
                label: "累计浮盈",
                value: hideBalance ? "¥****" : CurrencyFormatter.cnyTile(totalUnrealizedPnL, signed: true),
                valueColor: Color.pnlColor(totalUnrealizedPnL)
            )
        }
    }

    private var totalUnrealizedPnL: Double {
        let rmap = rateMap
        return positions.reduce(0.0) { sum, p in
            sum + p.unrealizedPnL * (rmap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
    }

    private var breakdownCard: some View {
        Card(title: "资产分布", trailingText: "\(breakdown.segments.count) 类") {
            NavigationLink {
                RebalanceView()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption.weight(.semibold))
                    Text("查看再平衡建议")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.Palette.accent)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            breakdownContent
        }
    }

    private var breakdownContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            allocationBar
                .padding(.top, 6)

            VStack(spacing: 14) {
                ForEach(Array(breakdown.segments.enumerated()), id: \.offset) { _, seg in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: seg.colorHex))
                            .frame(width: 9, height: 9)
                        Text(seg.label)
                            .font(.subheadline)
                        Spacer()
                        Text(hideBalance ? "¥****" : CurrencyFormatter.cnyString(seg.value))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(percentString(seg.value))
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var allocationBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(breakdown.segments.enumerated()), id: \.offset) { _, seg in
                    Color(hex: seg.colorHex)
                        .frame(width: max(2, geo.size.width * (seg.value / max(breakdown.total, 0.01)) - 2))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }

    private func percentString(_ value: Double) -> String {
        guard breakdown.total > 0 else { return "0%" }
        return String(format: "%.1f%%", value / breakdown.total * 100)
    }

    private var trendCard: some View {
        let data = aggregatedSnapshots
        let chg: Double = (data.first.flatMap { f in data.last.map { l in l.totalValueCNY - f.totalValueCNY } }) ?? 0
        let pct: Double = (data.first.flatMap { f in data.last.map { l in f.totalValueCNY > 0 ? (l.totalValueCNY - f.totalValueCNY) / f.totalValueCNY * 100 : 0 } }) ?? 0

        return Card(title: "走势", trailingText: trendRange.titleSuffix) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: chg >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.bold))
                        Text(CurrencyFormatter.percent(pct))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.pnlColor(chg))

                    Spacer()

                    Picker("时段", selection: $trendRangeRaw) {
                        ForEach(TrendRange.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                if data.count < 2 {
                    insufficientDataView
                } else {
                    chart(for: data)
                }
            }
        }
    }

    private var insufficientDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("数据不足")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(insufficientHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var insufficientHint: String {
        switch trendRange {
        case .day: return "继续使用应用积累每日快照"
        case .week: return "至少需要 2 个完整周的数据,继续使用应用积累"
        case .month: return "至少需要 2 个完整月的数据,继续使用应用积累"
        case .year: return "至少需要 2 个完整年的数据,继续使用应用积累"
        }
    }

    @ViewBuilder
    private func chart(for data: [DailySnapshot]) -> some View {
        let stride = trendRange.axisStride
        Chart(data) { snap in
            LineMark(
                x: .value("日期", snap.date),
                y: .value("总资产", snap.totalValueCNY)
            )
            .foregroundStyle(Theme.Palette.heroAccent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("日期", snap.date),
                y: .value("总资产", snap.totalValueCNY)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.Palette.heroAccent.opacity(0.35), Theme.Palette.heroAccent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(CurrencyFormatter.cnyShort(v))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: stride.0, count: stride.1)) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
    }

    private func axisLabel(for date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        switch trendRange {
        case .day:
            f.dateFormat = "M月d日"
        case .week:
            f.dateFormat = "M月d日"
        case .month:
            // 一月用 yyyy年1月 标年份,其他月只显示 M月
            let month = cal.component(.month, from: date)
            f.dateFormat = month == 1 ? "yyyy年1月" : "M月"
        case .year:
            f.dateFormat = "yyyy年"
        }
        return f.string(from: date)
    }

    @ViewBuilder
    private var pendingCard: some View {
        if !pendingTxs.isEmpty {
            Card(title: "在途交易", trailingText: "\(pendingTxs.count) 笔") {
                VStack(spacing: 14) {
                    ForEach(pendingTxs) { tx in
                        TransactionRow(tx: tx, hideAmount: hideBalance)
                        if tx.id != pendingTxs.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private var recentTransactionsCard: some View {
        Card(title: "最近交易", trailingText: "\(allTxs.count) 笔") {
            if recentTxs.isEmpty {
                Text("还没有交易记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 14) {
                    ForEach(recentTxs) { tx in
                        TransactionRow(tx: tx, hideAmount: hideBalance)
                        if tx.id != recentTxs.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let tx: TransactionRecord
    var hideAmount: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBg.opacity(0.15))
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconBg)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tx.type.displayName)
                        .font(.subheadline.weight(.semibold))
                    if tx.status == .pending {
                        PillTag(text: "在途", color: .orange)
                    } else if tx.status == .confirmed {
                        PillTag(text: "已确认", color: .blue)
                    }
                }
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(hideAmount ? "¥****" : amountText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                Text(DateUtil.relative(tx.tradeDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
        case .dcaDeduct, .dcaConfirm: return Theme.Palette.heroAccent
        case .buyFund, .buyStock: return .pnlPositive
        case .sellFund, .sellStock: return .pnlNegative
        case .dividend: return .orange
        case .transfer: return .purple
        case .deposit: return .green
        case .withdraw: return .red
        }
    }

    private var subtitleText: String {
        if tx.hasSourceBalanceTrail, !tx.fromAccountName.isEmpty {
            let before = String(format: "%.2f", tx.sourceBalanceBefore)
            let after = String(format: "%.2f", tx.sourceBalanceAfter)
            return "\(tx.fromAccountName) \(before) → \(after)"
        }
        if !tx.assetName.isEmpty { return "\(tx.assetName) · \(tx.assetCode)" }
        if !tx.toAccountName.isEmpty { return tx.toAccountName }
        return tx.note
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
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
