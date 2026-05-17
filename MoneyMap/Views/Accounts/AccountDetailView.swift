import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account
    @Query private var allPositions: [Position]
    @Query private var rates: [ExchangeRate]

    @State private var showEditSheet = false
    @State private var showAddPositionSheet = false
    @State private var showDeleteAlert = false

    private var positions: [Position] {
        allPositions.filter { $0.account?.id == account.id }
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var returns: AccountReturns {
        AccountReturnsService.compute(account: account, positions: positions, rates: rateMap)
    }

    private var totalValueCNY: Double {
        let cashFx = rateMap[account.currency.rawValue] ?? 1.0
        let cashCNY = account.cashBalance * cashFx
        let posCNY = positions.reduce(0.0) { sum, p in
            let fx = rateMap[p.effectiveCurrency.rawValue] ?? 1.0
            return sum + p.marketValue * fx
        }
        return cashCNY + posCNY
    }

    private var isInvestmentAccount: Bool {
        account.type.isInvestment
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHero

                if isInvestmentAccount && !positions.isEmpty {
                    returnsCard
                }

                cashCard

                if !positions.isEmpty {
                    positionsCard
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("编辑账户", systemImage: "pencil")
                    }
                    if isInvestmentAccount {
                        Button {
                            showAddPositionSheet = true
                        } label: {
                            Label("添加持仓", systemImage: "plus.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除账户", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditAccountSheet(account: account)
        }
        .sheet(isPresented: $showAddPositionSheet) {
            AddPositionSheet(account: account)
        }
        .alert("确认删除?", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                context.delete(account)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("将永久删除「\(account.name)」及其所有持仓和相关交易引用。")
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 6) {
                Image(systemName: account.type.iconName)
                    .font(.caption.weight(.semibold))
                Text(account.type.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)

            AmountText(amount: totalValueCNY, size: .hero)
                .foregroundStyle(.primary)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.tertiary)
                    if hasMultipleCurrencies {
                        Text("含外币持仓 · CNY 折算")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if account.currency != .cny {
                        Text("CNY 折算 · 原 \(currencyLabel(account.currency))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isInvestmentAccount && !positions.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: returns.dailyPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.footnote.weight(.bold))
                            Text(CurrencyFormatter.signedCNY(returns.dailyPnL))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        Text(CurrencyFormatter.percent(returns.dailyPnLPercent))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.pnlColor(returns.dailyPnL))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardStyle()
    }

    private func currencyLabel(_ c: CurrencyCode) -> String {
        switch c {
        case .cny: return "人民币"
        case .hkd: return "港币"
        case .usd: return "美元"
        }
    }

    private var hasMultipleCurrencies: Bool {
        let set = Set(positions.map { $0.effectiveCurrency })
        if set.count > 1 { return true }
        if let only = set.first, only != account.currency, !positions.isEmpty { return true }
        return false
    }

    private var returnsCard: some View {
        Card(title: "收益概览") {
            VStack(spacing: 12) {
                MetricRow(
                    label: "今日",
                    value: CurrencyFormatter.signedCNY(returns.dailyPnL),
                    valueColor: Color.pnlColor(returns.dailyPnL),
                    valueSubtitle: CurrencyFormatter.percent(returns.dailyPnLPercent)
                )
                Divider().opacity(0.4)
                MetricRow(
                    label: "近 7 天",
                    value: CurrencyFormatter.signedCNY(returns.weeklyPnL),
                    valueColor: Color.pnlColor(returns.weeklyPnL),
                    valueSubtitle: CurrencyFormatter.percent(returns.weeklyPnLPercent)
                )
                Divider().opacity(0.4)
                MetricRow(
                    label: "近 30 天",
                    value: CurrencyFormatter.signedCNY(returns.monthlyPnL),
                    valueColor: Color.pnlColor(returns.monthlyPnL),
                    valueSubtitle: CurrencyFormatter.percent(returns.monthlyPnLPercent)
                )
                Divider().opacity(0.4)
                MetricRow(
                    label: "今年至今",
                    value: CurrencyFormatter.signedCNY(returns.ytdPnL),
                    valueColor: Color.pnlColor(returns.ytdPnL),
                    valueSubtitle: CurrencyFormatter.percent(returns.ytdPnLPercent)
                )
                Divider().opacity(0.4)
                MetricRow(
                    label: "累计盈亏",
                    value: CurrencyFormatter.signedCNY(returns.unrealizedPnL),
                    valueColor: Color.pnlColor(returns.unrealizedPnL),
                    valueSubtitle: CurrencyFormatter.percent(returns.unrealizedPnLPercent)
                )
                Divider().opacity(0.4)
                MetricRow(
                    label: "年化收益率",
                    value: CurrencyFormatter.percent(returns.annualizedReturnPercent),
                    valueColor: Color.pnlColor(returns.annualizedReturnPercent)
                )
            }
        }
    }

    private var cashCard: some View {
        Card(title: "现金余额") {
            HStack {
                Text(currencyLabel(account.currency))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(account.currency.symbol)\(String(format: "%.2f", account.cashBalance))")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
        }
    }

    @State private var editingPosition: Position?
    @State private var deletingPosition: Position?

    private var positionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("持仓")
                    .font(.headline)
                Spacer()
                Text("\(positions.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            List {
                ForEach(positions) { pos in
                    PositionRow(position: pos)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingPosition = pos
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                editingPosition = pos
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(12)
            .scrollDisabled(true)
            .frame(height: CGFloat(positions.count) * 96 + CGFloat(max(0, positions.count - 1)) * 12 + 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .sheet(item: $editingPosition) { pos in
            EditPositionSheet(position: pos)
        }
        .alert("删除持仓?", isPresented: Binding(
            get: { deletingPosition != nil },
            set: { if !$0 { deletingPosition = nil } }
        )) {
            Button("取消", role: .cancel) { deletingPosition = nil }
            Button("删除", role: .destructive) {
                if let p = deletingPosition {
                    context.delete(p)
                    try? context.save()
                }
                deletingPosition = nil
            }
        } message: {
            if let p = deletingPosition {
                Text("将永久删除「\(p.assetName)」持仓记录。已经发生的交易记录会保留。")
            }
        }
    }

}

struct PositionRow: View {
    let position: Position

    private var currency: CurrencyCode { position.effectiveCurrency }

    private var sharesUnit: String {
        switch position.assetClass {
        case .gold: return "克"
        case .stockA, .stockHK, .stockUS: return "股"
        default: return "份"
        }
    }

    /// 成本价的合理精度——黄金每克 2 位足够,基金 3-4 位才能显示净值微动
    private var costFormat: String {
        switch position.assetClass {
        case .gold, .stockA, .stockHK, .stockUS: return "%.2f"
        default: return "%.4f"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(position.assetName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(position.assetCode)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(currency.symbol)\(String(format: "%.2f", position.marketValue))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Image(systemName: position.dailyPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.weight(.bold))
                        Text(CurrencyFormatter.percent(position.dailyPnLPercent))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.pnlColor(position.dailyPnL))
                }
            }

            HStack(spacing: 6) {
                metaItem(label: "持有", value: "\(CurrencyFormatter.shares(position.shares)) \(sharesUnit)")
                Divider().frame(height: 12)
                metaItem(label: "成本", value: "\(currency.symbol)\(String(format: costFormat, position.avgCost))")
                Spacer(minLength: 6)
                Text(CurrencyFormatter.percent(position.unrealizedPnLPercent))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(Color.pnlColor(position.unrealizedPnL))
            }
        }
    }

    private func metaItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
