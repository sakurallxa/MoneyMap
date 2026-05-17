import SwiftUI
import SwiftData

struct AddPositionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account

    @State private var assetCode = ""
    @State private var assetName = ""
    @State private var sharesText = ""
    @State private var avgCostText = ""
    @State private var lastPriceText = ""
    @State private var isFetching = false
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    enum Field { case code, name, shares, avgCost, price }

    private var canSave: Bool {
        !assetCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !assetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(sharesText) ?? 0 > 0
    }

    private var codePlaceholder: String {
        switch account.type {
        case .fundApp: return "基金代码,如 005827"
        case .brokerA: return "股票代码,如 600519 或 000001"
        case .brokerHK: return "港股代码,如 00700"
        case .brokerUS: return "美股代码,如 AAPL"
        case .brokerHKUS: return "如 0700.HK 或 AAPL.US"
        case .goldDeposit: return "如 AU9999 或自定义编码"
        case .goldPhysical: return "如 GOLDBAR_100G 或自定义"
        default: return "资产代码"
        }
    }

    private var sharesPlaceholder: String {
        switch account.type {
        case .goldDeposit, .goldPhysical: return "必填,单位克"
        default: return "必填,如 1234.56"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("所属账户")
                        Spacer()
                        Text(account.name)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("资产信息") {
                    HStack {
                        TextField(codePlaceholder, text: $assetCode)
                            .autocapitalization(.allCharacters)
                            .focused($focusedField, equals: .code)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .shares }
                        if isFetching {
                            ProgressView().scaleEffect(0.7)
                        }
                    }
                    TextField("资产名称", text: $assetName)
                        .focused($focusedField, equals: .name)
                }

                Section(account.type.isGold ? "持有克数" : "持仓数量") {
                    HStack {
                        Text(account.type.isGold ? "持有克数" : "持有份额/股数")
                        Spacer()
                        TextField(sharesPlaceholder, text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .shares)
                    }
                }

                Section(account.type.isGold ? "当前金价" : "当前价格") {
                    HStack {
                        Text(account.type.isGold ? "金价(¥/克)" : "当前净值/股价")
                        Spacer()
                        TextField("自动获取", text: $lastPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .price)
                    }
                }

                Section {
                    HStack {
                        Text("平均持仓成本")
                        Spacer()
                        TextField("可留空", text: $avgCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .avgCost)
                    }
                } header: {
                    Text("成本价(选填)")
                } footer: {
                    Text("买入这只资产时的平均价,用于算「累计浮盈」。\n• 支付宝:基金详情 → 持有 → 成本价\n• 天天基金/蛋卷:持仓详情里的「持仓成本价」\n• 券商 App:通常叫「持仓均价」或「成本价」")
                }
            }
            .navigationTitle("添加持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: assetCode) { _, newValue in
                scheduleFetch(for: newValue)
            }
        }
    }

    private func scheduleFetch(for code: String) {
        fetchTask?.cancel()
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        // 黄金账户:无需精确代码,只要输入即触发
        let minLen = account.type.isGold ? 2 : 4
        guard trimmed.count >= minLen else { return }
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await fetchPrice(for: trimmed)
        }
    }

    private func fetchPrice(for codeInput: String) async {
        let code = codeInput.uppercased()
        await MainActor.run { isFetching = true }
        defer { Task { @MainActor in isFetching = false } }

        do {
            let result: PriceQuoteResult
            switch account.type {
            case .fundApp:
                if GoldRecognizer.isGoldAssetCode(code) {
                    result = try await PriceService.fetchAShare(code: code)
                } else {
                    result = try await PriceService.fetchFundNAV(code: code)
                }
            case .brokerA:
                result = try await PriceService.fetchAShare(code: code)
            case .brokerHK:
                let clean = code.replacingOccurrences(of: ".HK", with: "")
                result = try await PriceService.fetchHKStock(code: clean)
            case .brokerUS:
                let clean = code.replacingOccurrences(of: ".US", with: "")
                result = try await PriceService.fetchUSStock(symbol: clean)
            case .brokerHKUS:
                if code.hasSuffix(".HK") {
                    let clean = code.replacingOccurrences(of: ".HK", with: "")
                    result = try await PriceService.fetchHKStock(code: clean)
                } else {
                    let clean = code.replacingOccurrences(of: ".US", with: "")
                    result = try await PriceService.fetchUSStock(symbol: clean)
                }
            case .goldDeposit, .goldPhysical:
                result = try await PriceService.fetchGoldSpotCNYPerGram()
            default:
                return
            }
            await MainActor.run {
                lastPriceText = String(format: "%.4f", result.price)
                if assetName.trimmingCharacters(in: .whitespaces).isEmpty, let name = result.assetName, !name.isEmpty {
                    assetName = name
                }
            }
        } catch {
            // 静默失败,用户可手动填
        }
    }

    private func save() {
        let lastPrice = Double(lastPriceText) ?? 0
        let code = assetCode.trimmingCharacters(in: .whitespaces).uppercased()
        let finalCode: String
        switch account.type {
        case .brokerHK where !code.hasSuffix(".HK"):
            finalCode = code + ".HK"
        case .brokerUS where !code.hasSuffix(".US"):
            finalCode = code + ".US"
        default:
            finalCode = code
        }
        let pos = Position(
            account: account,
            assetCode: finalCode,
            assetName: assetName.trimmingCharacters(in: .whitespaces),
            shares: Double(sharesText) ?? 0,
            avgCost: Double(avgCostText) ?? 0,
            lastPrice: lastPrice,
            prevClosePrice: lastPrice,
            weekAgoPrice: lastPrice,
            monthAgoPrice: lastPrice,
            yearStartPrice: lastPrice
        )
        context.insert(pos)
        try? context.save()
        dismiss()
    }
}
