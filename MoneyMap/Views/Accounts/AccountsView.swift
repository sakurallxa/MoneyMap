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
            ScrollView {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "还没有账户",
                        systemImage: "wallet.pass",
                        description: Text("点击右上角 + 添加")
                    )
                    .padding(.top, 100)
                } else {
                    VStack(spacing: 14) {
                        summaryCard

                        if !investmentAccounts.isEmpty {
                            sectionGroup(title: "投资账户", subtitle: "\(investmentAccounts.count) 个 · 合计 \(formatCNY(investmentTotal))", accounts: investmentAccounts)
                        }
                        if !cashAccounts.isEmpty {
                            sectionGroup(title: "现金账户", subtitle: "\(cashAccounts.count) 个 · 合计 \(formatCNY(cashTotal))", accounts: cashAccounts)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("账户")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(accounts.count) 个 · 合计 \(hideBalance ? kHiddenAmountMask : formatCNY(grandTotal))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.Palette.accent)
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Theme.Palette.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAccountSheet()
            }
        }
    }

    /// 顶部 summary 卡:投资类 + 现金类双列 + 占比 stacked bar
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 0) {
                summaryColumn(label: "投资类", value: investmentTotal, share: grandTotal > 0 ? investmentTotal / grandTotal : 0, color: Theme.Palette.accent)
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 12)
                summaryColumn(label: "现金类", value: cashTotal, share: grandTotal > 0 ? cashTotal / grandTotal : 0, color: Color(hex: "#5B8FF9"))
            }

            // stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if grandTotal > 0 {
                        Theme.Palette.accent
                            .frame(width: max(0, geo.size.width * (investmentTotal / grandTotal) - 1))
                        Color(hex: "#5B8FF9")
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
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(hideBalance ? kHiddenAmountMask : formatCNY(value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .kerning(-0.4)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
                .accessibilityLabel(value.accessibilityAmountLabel(prefix: label, hidden: hideBalance))
            Text(hideBalance ? "占比 ··%" : String(format: "占比 %.1f%%", share * 100))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionGroup(title: String, subtitle: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(hideBalance ? kHiddenAmountMask : subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            VStack(spacing: 10) {
                ForEach(accounts) { acc in
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
                }
            }
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

    private var hasInvestments: Bool { !positions.isEmpty }

    private var totalCNY: Double {
        let cashFx = rateMap[account.currency.rawValue] ?? 1.0
        let cashCNY = account.cashBalance * cashFx
        let posCNY = positions.reduce(0.0) { sum, p in
            sum + p.marketValue * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
        return cashCNY + posCNY
    }

    private var todayPnL: Double {
        positions.reduce(0.0) { sum, p in
            sum + p.dailyPnL * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
    }

    private var todayPnLPct: Double {
        let prev = positions.reduce(0.0) { sum, p in
            sum + p.shares * p.prevClosePrice * (rateMap[p.effectiveCurrency.rawValue] ?? 1.0)
        }
        guard prev > 0 else { return 0 }
        return todayPnL / prev * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            // 类别色 icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(typeColor.opacity(0.18))
                Image(systemName: account.type.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(typeColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if hasInvestments {
                    HStack(spacing: 3) {
                        Image(systemName: todayPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(hideBalance ? "¥····" : (todayPnL >= 0 ? "+" : "-") + "¥\(formatShort(abs(todayPnL)))")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                        Text(hideBalance ? "··%" : String(format: "%+.2f%%", todayPnLPct))
                            .font(.system(size: 11))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.pnlColor(todayPnL))
                } else if !account.note.isEmpty {
                    Text(account.note)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(hideBalance ? kHiddenAmountMask : CurrencyFormatter.cnyString(totalCNY))
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                if hasInvestments {
                    Text("\(positions.count) 个持仓")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(account.currency.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var typeColor: Color {
        switch account.type {
        case .cash: return Color(hex: "#5B8FF9")
        case .moneyFund: return Color(hex: "#7B68EE")
        case .fundApp: return Color(hex: "#F4B860")
        case .brokerA: return Color(hex: "#E63946")
        case .brokerHK: return Color(hex: "#2A9D8F")
        case .brokerUS: return Color(hex: "#1ABC9C")
        case .brokerHKUS: return Color(hex: "#2A9D8F")
        case .goldDeposit, .goldPhysical: return Color(hex: "#D4AF37")
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
