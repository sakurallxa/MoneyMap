import SwiftUI
import SwiftData

enum TradeAction: String {
    case buy = "BUY"
    case sell = "SELL"

    var displayName: String {
        switch self {
        case .buy: return "买入"
        case .sell: return "卖出"
        }
    }
}

struct RebalancePrefill: Identifiable {
    let id = UUID()
    let action: TradeAction
    let assetClass: AssetClass
    let amount: Double
}

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var allPositions: [Position]

    let prefill: RebalancePrefill?

    @State private var action: TradeAction
    @State private var assetClassFilter: AssetClass?
    @State private var selectedPositionID: UUID?
    @State private var selectedCashAccountID: UUID?
    @State private var amountText: String
    @State private var priceText: String = ""
    @State private var sharesText: String = ""
    @State private var feeText: String = ""
    @State private var note: String = ""
    @State private var lockedField: LockedField = .amount

    enum LockedField {
        case amount, shares
    }

    init(prefill: RebalancePrefill? = nil) {
        self.prefill = prefill
        _action = State(initialValue: prefill?.action ?? .buy)
        _amountText = State(initialValue: prefill.map { String(format: "%.2f", $0.amount) } ?? "")
        _assetClassFilter = State(initialValue: prefill?.assetClass)
    }

    private var candidatePositions: [Position] {
        guard let cls = assetClassFilter else { return allPositions }
        return allPositions.filter { $0.assetClass == cls }
    }

    private var cashAccounts: [Account] {
        accounts.filter { $0.type == .cash || $0.type == .moneyFund }
    }

    private var selectedPosition: Position? {
        allPositions.first { $0.id == selectedPositionID }
    }

    private var selectedCashAccount: Account? {
        accounts.first { $0.id == selectedCashAccountID }
    }

    private var canSave: Bool {
        selectedPosition != nil &&
        selectedCashAccount != nil &&
        (Double(amountText) ?? 0) > 0 &&
        (Double(priceText) ?? 0) > 0 &&
        (Double(sharesText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("方向", selection: $action) {
                        Text("买入").tag(TradeAction.buy)
                        Text("卖出").tag(TradeAction.sell)
                    }
                    .pickerStyle(.segmented)

                    if let cls = assetClassFilter {
                        HStack {
                            Text("资产类别")
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: cls.hexColor))
                                    .frame(width: 8, height: 8)
                                Text(cls.displayName)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("交易方向")
                }

                Section {
                    if candidatePositions.isEmpty {
                        Text("该类别下还没有持仓 · 请先去对应账户「添加持仓」")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Picker("选择资产", selection: $selectedPositionID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(candidatePositions) { pos in
                                Text("\(pos.assetName) · \(pos.assetCode)").tag(Optional(pos.id))
                            }
                        }
                        if let pos = selectedPosition {
                            HStack {
                                Text("当前持有")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pos.effectiveCurrency.symbol)\(formatMarketValue(pos.marketValue)) · \(pos.account?.name ?? "—")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("具体资产")
                }

                Section {
                    Picker(action == .buy ? "扣款账户" : "收款账户", selection: $selectedCashAccountID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(cashAccounts) { acc in
                            Text(acc.name).tag(Optional(acc.id))
                        }
                    }
                } header: {
                    Text(action == .buy ? "扣款来源" : "收款去向")
                }

                Section {
                    HStack {
                        Text("当前价格")
                        Spacer()
                        TextField("0.0000", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: priceText) { _, _ in
                                recalcFromLocked()
                            }
                    }
                    HStack {
                        Text("金额")
                        Spacer()
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onTapGesture { lockedField = .amount }
                            .onChange(of: amountText) { _, _ in
                                if lockedField == .amount { recalcFromLocked() }
                            }
                    }
                    HStack {
                        Text("份额")
                        Spacer()
                        TextField("0.00", text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onTapGesture { lockedField = .shares }
                            .onChange(of: sharesText) { _, _ in
                                if lockedField == .shares { recalcFromLocked() }
                            }
                    }
                } header: {
                    Text("交易金额")
                } footer: {
                    Text(lockedField == .amount ? "改金额时,份额自动按价格折算" : "改份额时,金额自动按价格折算")
                }

                Section {
                    HStack {
                        Text("手续费(可空)")
                        Spacer()
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $feeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("备注(可空)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(action.displayName + " · " + (assetClassFilter?.displayName ?? "交易"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { autoSelectDefaults() }
            .onChange(of: selectedPositionID) { _, _ in
                if let pos = selectedPosition, priceText.isEmpty || Double(priceText) == 0 {
                    priceText = String(format: "%.4f", pos.lastPrice)
                    recalcFromLocked()
                }
            }
        }
    }

    /// 市值格式 — 千分位 + 2 位小数,前缀由调用方拼 currency symbol。
    private func formatMarketValue(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private func autoSelectDefaults() {
        if selectedPositionID == nil, let first = candidatePositions.first {
            selectedPositionID = first.id
        }
        if selectedCashAccountID == nil, let first = cashAccounts.first {
            selectedCashAccountID = first.id
        }
        if let pos = selectedPosition, priceText.isEmpty {
            priceText = String(format: "%.4f", pos.lastPrice)
            recalcFromLocked()
        }
    }

    private func recalcFromLocked() {
        guard let price = Double(priceText), price > 0 else { return }
        switch lockedField {
        case .amount:
            if let amount = Double(amountText), amount > 0 {
                sharesText = String(format: "%.4f", amount / price)
            }
        case .shares:
            if let shares = Double(sharesText), shares > 0 {
                amountText = String(format: "%.2f", shares * price)
            }
        }
    }

    private func save() {
        guard let pos = selectedPosition,
              let cash = selectedCashAccount,
              let posAccount = pos.account,
              let amount = Double(amountText), amount > 0,
              let price = Double(priceText), price > 0,
              let shares = Double(sharesText), shares > 0
        else { return }
        let fee = Double(feeText) ?? 0

        let now = Date()
        let cashBefore = cash.cashBalance
        let cashDelta = action == .buy ? -(amount + fee) : (amount - fee)
        cash.cashBalance += cashDelta
        cash.updatedAt = now

        switch action {
        case .buy:
            let newTotal = pos.shares + shares
            let newCost = newTotal > 0 ? (pos.totalCost + amount) / newTotal : 0
            pos.shares = newTotal
            pos.avgCost = newCost
        case .sell:
            pos.shares = max(0, pos.shares - shares)
        }
        pos.lastPrice = price
        pos.updatedAt = now

        let txType: TransactionType = {
            switch (action, pos.assetClass) {
            case (.buy, .fund): return .buyFund
            case (.sell, .fund): return .sellFund
            case (.buy, _): return .buyStock
            case (.sell, _): return .sellStock
            }
        }()

        let tx = TransactionRecord(
            tradeDate: now,
            type: txType,
            status: .completed,
            fromAccountID: action == .buy ? cash.id : posAccount.id,
            toAccountID: action == .buy ? posAccount.id : cash.id,
            fromAccountName: action == .buy ? cash.name : posAccount.name,
            toAccountName: action == .buy ? posAccount.name : cash.name,
            assetCode: pos.assetCode,
            assetName: pos.assetName,
            amount: amount,
            shares: shares,
            price: price,
            fee: fee,
            note: note.trimmingCharacters(in: .whitespaces),
            sourceBalanceBefore: action == .buy ? cashBefore : -1,
            sourceBalanceAfter: action == .buy ? cash.cashBalance : -1,
            targetBalanceBefore: action == .sell ? cashBefore : -1,
            targetBalanceAfter: action == .sell ? cash.cashBalance : -1
        )
        context.insert(tx)
        try? context.save()
        dismiss()
    }
}
