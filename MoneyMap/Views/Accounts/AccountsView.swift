import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var positions: [Position]
    @Query private var rates: [ExchangeRate]

    @State private var showAddSheet = false
    @AppStorage("hideBalance") private var hideBalance = false

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    /// 投资类账户的合计 CNY(包含持仓市值 + 该账户的现金)
    private var investmentTotal: Double {
        let invAccs = accounts.filter { $0.type.isInvestment }
        let invIds = Set(invAccs.map { $0.id })
        let cash = invAccs.reduce(0.0) { sum, acc in
            sum + acc.cashBalance * (rateMap[acc.currency.rawValue] ?? 1.0)
        }
        let posValue = positions
            .filter { p in p.account.map { invIds.contains($0.id) } ?? false }
            .reduce(0.0) { sum, p in
                sum + p.marketValue * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
            }
        return cash + posValue
    }

    /// 现金类账户的合计 CNY
    private var cashTotal: Double {
        accounts.filter { !$0.type.isInvestment }.reduce(0.0) { sum, acc in
            sum + acc.cashBalance * (rateMap[acc.currency.rawValue] ?? 1.0)
        }
    }

    private var grandTotal: Double { investmentTotal + cashTotal }

    private var investmentAccounts: [Account] { accounts.filter { $0.type.isInvestment } }
    private var cashAccounts: [Account] { accounts.filter { !$0.type.isInvestment } }

    var body: some View {
        NavigationStack {
            if accounts.isEmpty {
                AccountsEmptyV2(addAction: { showAddSheet = true })
                    .navigationBarHidden(true)
                    .sheet(isPresented: $showAddSheet) {
                        AddAccountSheet()
                    }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        headerRow
                        summaryCard

                        if !investmentAccounts.isEmpty {
                            sectionGroup(title: "投资账户", count: investmentAccounts.count, accounts: investmentAccounts)
                        }
                        if !cashAccounts.isEmpty {
                            sectionGroup(title: "现金账户", count: cashAccounts.count, accounts: cashAccounts)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
                .navigationBarHidden(true)
                .sheet(isPresented: $showAddSheet) {
                    AddAccountSheet()
                }
            }
        }
    }

    /// 顶部:账户标题 + 右侧「眼睛 + 」按钮(P0-005 PageHeader,P0-006 全局隐藏开关入口)
    private var headerRow: some View {
        PageHeader(title: "账户", subtitle: accountsSubtitle) {
            HStack(spacing: 6) {
                HideBalanceToggle()
                BronzeAddButton { showAddSheet = true }
            }
        }
    }

    /// P1-013:摘要型副标统一(原来缺失,现填上)
    private var accountsSubtitle: String? {
        guard !accounts.isEmpty else { return nil }
        let total = accounts.count
        let inv = investmentAccounts.count
        if total == 0 { return nil }
        if inv == 0 { return "\(total) 个账户 · 全部现金类" }
        return "\(total) 个账户 · 投资 \(inv) · 现金 \(total - inv)"
    }

    /// 顶部 summary 卡:投资类 + 现金类双列 + 占比 stacked bar
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 0) {
                summaryColumn(label: "投资类", value: investmentTotal, share: grandTotal > 0 ? investmentTotal / grandTotal : 0, color: Theme.Palette.accent)
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 12)
                summaryColumn(label: "现金类", value: cashTotal, share: grandTotal > 0 ? cashTotal / grandTotal : 0, color: Theme.Palette.segmentCash)
            }

            // stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if grandTotal > 0 {
                        Theme.Palette.accent
                            .frame(width: max(0, geo.size.width * (investmentTotal / grandTotal) - 1))
                        Theme.Palette.segmentCash
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.black.opacity(0.08)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func summaryColumn(label: String, value: Double, share: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(Theme.serif(12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            MoneyText(
                value: value,
                scale: .metric,
                hidden: hideBalance
            )
            .accessibilityLabel(value.accessibilityAmountLabel(prefix: label, hidden: hideBalance))
            Text(hideBalance ? "占比 ··%" : String(format: "占比 %.1f%%", share * 100))
                .font(Theme.serif(11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionGroup(title: String, count: Int, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                // P2-020:把空态的自绘 clipboard 图标缩到 24px 复用到 section header
                IconAccountClipboard(size: 24)
                Text(title)
                    .font(Theme.serif(14, weight: .bold))
                    .foregroundStyle(.primary)
                Text("\(count) 个")
                    .font(Theme.serif(12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 8)

            VStack(spacing: 0) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, acc in
                    NavigationLink {
                        AccountDetailView(account: acc)
                    } label: {
                        AccountRow(
                            account: acc,
                            positions: positions.filter { $0.account?.id == acc.id },
                            rateMap: rateMap,
                            hideBalance: hideBalance
                        )
                    }
                    .buttonStyle(.plain)

                    if idx < accounts.count - 1 {
                        Divider()
                            .opacity(0.5)
                            .padding(.leading, 70)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .cardElevation()
        }
    }

    private func formatCNY(_ v: Double) -> String {
        CurrencyFormatter.cnyString(v)
    }
}

struct AccountRow: View {
    let account: Account
    let positions: [Position]
    let rateMap: [String: Double]
    let hideBalance: Bool

    private var isInvestmentType: Bool { account.type.isInvestment }
    private var isGold: Bool { account.type.isGold }
    private var hasPositions: Bool { !positions.isEmpty }

    private var totalCNY: Double {
        let cashFx = rateMap[account.currency.rawValue] ?? 1.0
        let cashCNY = account.cashBalance * cashFx
        let posCNY = positions.reduce(0.0) { sum, p in
            sum + p.marketValue * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
        return cashCNY + posCNY
    }

    /// 投资账户(含黄金)累计盈亏 — 浮盈合计,CNY 折算。
    /// 现金账户没有"累计盈亏"概念,这里返回 0(不展示)。
    private var cumulativePnL: Double {
        guard isInvestmentType else { return 0 }
        return positions.reduce(0.0) { sum, p in
            sum + p.unrealizedPnL * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
    }

    /// 累计收益率 = 累计盈亏 / 总成本(CNY)
    private var cumulativePnLPct: Double {
        guard isInvestmentType else { return 0 }
        let cost = positions.reduce(0.0) { sum, p in
            sum + p.totalCost * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
        guard cost > 0 else { return 0 }
        return cumulativePnL / cost * 100
    }

    /// 黄金账户的总克数(shares 在黄金类里就是克)。
    private var totalGrams: Double {
        positions.reduce(0.0) { $0 + $1.shares }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 类别色 icon
            IconBadge(systemName: account.type.iconName, color: typeColor, size: .lg)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(Theme.serif(15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                subRow
            }

            Spacer(minLength: 6)

            // 右侧:有 rightSubLabel 时双行(投资/黄金);否则单行(现金类),避免 VStack 顶部错位
            if rightSubLabel.isEmpty {
                MoneyText(
                    value: totalCNY,
                    scale: .body,
                    hidden: hideBalance
                )
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    MoneyText(
                        value: totalCNY,
                        scale: .body,
                        hidden: hideBalance
                    )
                    Text(rightSubLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// 左下:投资类显示累计盈亏 + 累计%;现金类显示账户类型 + 币种。
    @ViewBuilder
    private var subRow: some View {
        if isInvestmentType {
            if hasPositions {
                HStack(spacing: 10) {     // 4 → 10:让金额和率有清晰的视觉间隔
                    MoneyText(
                        value: cumulativePnL,
                        scale: .caption,
                        signed: true,
                        hidden: hideBalance,
                        color: Color.pnlColor(cumulativePnL)
                    )
                    PercentText(
                        value: cumulativePnLPct,
                        size: 11,
                        signed: true,
                        hidden: hideBalance,
                        color: Color.pnlColor(cumulativePnL)
                    )
                }
            } else {
                Text("尚无持仓")
                    .font(Theme.serif(11))
                    .foregroundStyle(.tertiary)
            }
        } else {
            // 现金账户:账户类型 + 币种 (e.g. 储蓄卡 · CNY / 货币基金 · CNY)
            Text("\(account.type.displayName) · \(account.currency.rawValue)")
                .font(Theme.serif(11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    /// 右下:黄金账户显示克数;其他投资账户显示持仓数;现金账户留空。
    private var rightSubLabel: String {
        if isGold && hasPositions {
            return String(format: "%.2f g", totalGrams)
        }
        if isInvestmentType {
            return "\(positions.count) 个持仓"
        }
        return ""
    }

    private var typeColor: Color {
        switch account.type {
        case .cash: return Theme.Palette.segmentCash
        case .moneyFund: return Theme.Palette.segmentMoneyFund
        case .fundApp: return Theme.Palette.segmentFund
        case .brokerA: return Theme.Palette.segmentStockA
        case .brokerHK: return Theme.Palette.segmentStockHK
        case .brokerUS: return Theme.Palette.segmentStockUS
        case .brokerHKUS: return Theme.Palette.segmentStockHK
        case .goldDeposit, .goldPhysical: return Theme.Palette.segmentGold
        }
    }

    private func formatShort(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self, TargetAllocation.self], inMemory: true)
}
