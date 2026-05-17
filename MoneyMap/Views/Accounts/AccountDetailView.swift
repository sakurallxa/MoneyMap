import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account
    @Query private var allPositions: [Position]
    @Query private var rates: [ExchangeRate]
    @AppStorage("hideBalance") private var hideBalance = false

    @State private var showEditSheet = false
    @State private var showAddPositionSheet = false
    @State private var showDeleteAlert = false
    @State private var editingPosition: Position?
    @State private var deletingPosition: Position?

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

    private var isInvestmentAccount: Bool { account.type.isInvestment }

    private var hasMultipleCurrencies: Bool {
        let set = Set(positions.map { $0.effectiveCurrency })
        if set.count > 1 { return true }
        if let only = set.first, only != account.currency, !positions.isEmpty { return true }
        return false
    }

    var body: some View {
        List {
            Section { summaryHero }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)

            if isInvestmentAccount && !positions.isEmpty {
                Section { returnsCard }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    .listRowSeparator(.hidden)
            }

            Section { cashCard }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)

            if !positions.isEmpty {
                Section {
                    ForEach(positions) { pos in
                        PositionRow(position: pos)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingPosition = pos
                                } label: { Label("删除", systemImage: "trash") }
                                Button {
                                    editingPosition = pos
                                } label: { Label("编辑", systemImage: "pencil") }
                                .tint(.blue)
                            }
                    }
                } header: {
                    HStack {
                        Text("持仓 · \(positions.count) 项")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.2)
                            .foregroundStyle(.tertiary)
                            .textCase(nil)
                        Spacer()
                        Text("左滑可编辑/删除")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .textCase(nil)
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("编辑账户", systemImage: "pencil")
                    }
                    if isInvestmentAccount {
                        Button { showAddPositionSheet = true } label: {
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
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) { EditAccountSheet(account: account) }
        .sheet(isPresented: $showAddPositionSheet) { AddPositionSheet(account: account) }
        .sheet(item: $editingPosition) { pos in EditPositionSheet(position: pos) }
        .alert("删除账户?", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                let name = account.name
                context.delete(account)
                do {
                    try context.save()
                    ToastManager.shared.success("已删除「\(name)」")
                    dismiss()
                } catch {
                    ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
                }
            }
        } message: {
            Text("将永久删除「\(account.name)」及其所有持仓和相关交易引用。")
        }
        .alert("删除持仓?", isPresented: Binding(
            get: { deletingPosition != nil },
            set: { if !$0 { deletingPosition = nil } }
        )) {
            Button("取消", role: .cancel) { deletingPosition = nil }
            Button("删除", role: .destructive) {
                if let p = deletingPosition {
                    let name = p.assetName
                    context.delete(p)
                    do {
                        try context.save()
                        ToastManager.shared.success("已删除持仓「\(name)」")
                    } catch {
                        ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
                    }
                }
                deletingPosition = nil
            }
        } message: {
            if let p = deletingPosition {
                Text("将永久删除「\(p.assetName)」持仓记录。已经发生的交易记录会保留。")
            }
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: account.type.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(eyebrowText)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
            }
            .foregroundStyle(.secondary)

            Text(hideBalance ? kHiddenAmountMask : "¥\(formatNumber(totalValueCNY))")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityLabel(totalValueCNY.accessibilityAmountLabel(prefix: "账户总值", hidden: hideBalance))

            if isInvestmentAccount && !positions.isEmpty {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: returns.dailyPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(hideBalance ? "¥····" : CurrencyFormatter.signedCNY(returns.dailyPnL))
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                        Text(hideBalance ? "··%" : CurrencyFormatter.percent(returns.dailyPnLPercent))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.pnlColor(returns.dailyPnL))
                    .clipShape(Capsule())

                    Spacer()
                    Text("今日")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var eyebrowText: String {
        var parts = [account.type.displayName]
        if hasMultipleCurrencies {
            parts.append("含外币持仓")
            parts.append("CNY 折算")
        } else if account.currency != .cny {
            parts.append("CNY 折算")
        }
        return parts.joined(separator: " · ")
    }

    private var returnsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("收益概览")
                .font(.system(size: 17, weight: .bold))

            VStack(spacing: 12) {
                MetricRow(label: "今日",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.dailyPnL),
                          valueColor: Color.pnlColor(returns.dailyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.dailyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "近 7 天",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.weeklyPnL),
                          valueColor: Color.pnlColor(returns.weeklyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.weeklyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "近 30 天",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.monthlyPnL),
                          valueColor: Color.pnlColor(returns.monthlyPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.monthlyPnLPercent))
                Divider().opacity(0.4)
                MetricRow(label: "今年至今",
                          value: hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.ytdPnL),
                          valueColor: Color.pnlColor(returns.ytdPnL),
                          valueSubtitle: hideBalance ? "··%" : CurrencyFormatter.percent(returns.ytdPnLPercent))
            }

            // 底部累计盈亏 highlight 行
            HStack {
                Text("累计盈亏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hideBalance ? kHiddenAmountMask : CurrencyFormatter.signedCNY(returns.unrealizedPnL))
                        .font(.system(size: 17, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(returns.unrealizedPnL))
                    Text(hideBalance ? "··%" : CurrencyFormatter.percent(returns.unrealizedPnLPercent))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(returns.unrealizedPnL))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.035))
            )
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

    private var cashCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#5B8FF9").opacity(0.16))
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5B8FF9"))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("现金余额")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(currencyLabel(account.currency))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if account.currency != .cny {
                    Text(hideBalance ? kHiddenAmountMask : "\(account.currency.symbol)\(formatCash(account.cashBalance))")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                    Text(hideBalance ? kHiddenAmountMask : "≈ ¥\(formatCash(account.cashBalance * (rateMap[account.currency.rawValue] ?? 1.0)))")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                } else {
                    Text(hideBalance ? kHiddenAmountMask : "¥\(formatCash(account.cashBalance))")
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                }
            }

            Button {
                showEditSheet = true
            } label: {
                HStack(spacing: 3) {
                    Text("调账")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.Palette.accentDark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func currencyLabel(_ c: CurrencyCode) -> String {
        switch c {
        case .cny: return "人民币 CNY"
        case .hkd: return "港币 HKD"
        case .usd: return "美元 USD"
        }
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }

    private func formatCash(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "0.00"
    }
}

/// 持仓行 — 渐变 icon(资产名首字) + 名称 + 代码·持有 + 右侧市值 + 涨跌
struct PositionRow: View {
    let position: Position
    @AppStorage("hideBalance") private var hideBalance = false

    private var currency: CurrencyCode { position.effectiveCurrency }

    private var sharesUnit: String {
        switch position.assetClass {
        case .gold: return "克"
        case .stockA, .stockHK, .stockUS: return "股"
        default: return "份"
        }
    }

    private var iconColor: Color {
        switch position.assetClass {
        case .gold: return Color(hex: "#D4AF37")
        case .fund: return Color(hex: "#F4B860")
        case .stockA: return Color(hex: "#E63946")
        case .stockHK: return Color(hex: "#2A9D8F")
        case .stockUS: return Color(hex: "#1ABC9C")
        case .cash, .moneyFund: return Color(hex: "#5B8FF9")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 渐变 icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.28), iconColor.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text(String(position.assetName.prefix(1)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(position.assetName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text(position.assetCode)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("持 \(CurrencyFormatter.shares(position.shares)) \(sharesUnit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(hideBalance ? kHiddenAmountMask : "\(currency.symbol)\(formatValue(position.marketValue))")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(hideBalance ? "今日 ··%" : "今日 \(CurrencyFormatter.percent(position.dailyPnLPercent))")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(position.dailyPnL))
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(hideBalance ? "累计 ··%" : "累计 \(CurrencyFormatter.percent(position.unrealizedPnLPercent))")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(position.unrealizedPnL))
                }
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "0.00"
    }
}
