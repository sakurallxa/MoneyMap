import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var positions: [Position]

    @State private var showAddSheet = false
    @AppStorage("hideBalance") private var hideBalance = false

    private var groupedAccounts: [(AccountType, [Account])] {
        let dict = Dictionary(grouping: accounts) { $0.type }
        return AccountType.allCases.compactMap { type in
            guard let items = dict[type], !items.isEmpty else { return nil }
            return (type, items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "还没有账户",
                        systemImage: "wallet.pass",
                        description: Text("点击右上角 + 添加一个账户")
                    )
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 24, pinnedViews: []) {
                        ForEach(groupedAccounts, id: \.0) { type, items in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: type.iconName)
                                        .font(.caption.weight(.semibold))
                                    Text(type.displayName)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)

                                VStack(spacing: 12) {
                                    ForEach(items) { acc in
                                        NavigationLink {
                                            AccountDetailView(account: acc)
                                        } label: {
                                            AccountRow(
                                                account: acc,
                                                positions: positions.filter { $0.account?.id == acc.id },
                                                hideBalance: hideBalance
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("账户")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAccountSheet()
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let positions: [Position]
    var hideBalance: Bool = false

    @Query private var rates: [ExchangeRate]

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var returns: AccountReturns {
        AccountReturnsService.compute(account: account, positions: positions, rates: rateMap)
    }

    /// 账户总值统一以 CNY 显示,避免混币种账户加总不一致。
    private var totalValueCNY: Double {
        let cashFx = rateMap[account.currency.rawValue] ?? 1.0
        let cashCNY = account.cashBalance * cashFx
        let positionsCNY = positions.reduce(0) { sum, p in
            let fx = rateMap[p.effectiveCurrency.rawValue] ?? 1.0
            return sum + p.marketValue * fx
        }
        return cashCNY + positionsCNY
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if hasInvestments {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.grid.2x2.fill")
                            .font(.caption2)
                        Text("\(positions.count) 个持仓")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else if !account.note.isEmpty {
                    Text(account.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(hideBalance ? "¥****" : "¥\(formattedValue)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                if hasInvestments {
                    HStack(spacing: 3) {
                        Image(systemName: returns.dailyPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.weight(.bold))
                        Text(hideBalance ? "**%" : CurrencyFormatter.percent(returns.dailyPnLPercent))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.pnlColor(returns.dailyPnL))
                }
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var hasInvestments: Bool {
        !positions.isEmpty
    }

    private var formattedValue: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.minimumFractionDigits = 2
        n.maximumFractionDigits = 2
        return n.string(from: NSNumber(value: totalValueCNY)) ?? "0.00"
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
