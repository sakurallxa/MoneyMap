import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.tradeDate, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var positions: [Position]

    @State private var filter: FilterType = .all
    @State private var confirmingTx: TransactionRecord?
    @State private var confirmPrice: String = ""

    enum FilterType: String, CaseIterable {
        case all = "全部"
        case pending = "在途"
        case completed = "已完成"
    }

    private var filteredTxs: [TransactionRecord] {
        switch filter {
        case .all: return transactions
        case .pending: return transactions.filter { $0.status == .pending }
        case .completed: return transactions.filter { $0.status == .completed || $0.status == .confirmed }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("筛选", selection: $filter) {
                    ForEach(FilterType.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredTxs.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "暂无交易",
                        systemImage: "list.bullet.rectangle",
                        description: Text("定投生效或手动添加后,会出现在这里")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(filteredTxs) { tx in
                                HStack {
                                    TransactionRow(tx: tx)
                                        .padding(Theme.Spacing.md)
                                }
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                                .contextMenu {
                                    if tx.status == .pending && tx.type == .dcaDeduct {
                                        Button {
                                            confirmingTx = tx
                                            let suggested = positions.first(where: { $0.assetCode == tx.assetCode })?.lastPrice ?? 1.0
                                            confirmPrice = String(format: "%.4f", suggested)
                                        } label: {
                                            Label("确认份额", systemImage: "checkmark.circle")
                                        }
                                    }
                                    if tx.status == .pending {
                                        Button(role: .destructive) {
                                            context.delete(tx)
                                            try? context.save()
                                        } label: {
                                            Label("取消", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("交易记录")
            .alert("确认份额", isPresented: Binding(
                get: { confirmingTx != nil },
                set: { if !$0 { confirmingTx = nil } }
            )) {
                TextField("确认净值/股价", text: $confirmPrice)
                    .keyboardType(.decimalPad)
                Button("取消", role: .cancel) {
                    confirmingTx = nil
                }
                Button("确认") {
                    if let tx = confirmingTx, let price = Double(confirmPrice), price > 0 {
                        DCAService.manuallyConfirm(tx: tx, price: price, context: context)
                    }
                    confirmingTx = nil
                }
            } message: {
                if let tx = confirmingTx {
                    Text("将 \(tx.assetName) 的 ¥\(String(format: "%.2f", tx.amount)) 在当前净值下确认份额。")
                }
            }
        }
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
