import SwiftUI
import SwiftData

enum CodeFetchStatus {
    case idle, loading, success, failure
}

struct AddPositionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account

    @State private var assetCode = ""
    @State private var assetName = ""
    @State private var sharesText = ""
    @State private var avgCostText = ""
    @State private var lastPriceText = ""
    @State private var status: CodeFetchStatus = .idle
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    enum Field { case code, name, shares, avgCost, price }

    private var canSave: Bool {
        !assetCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !assetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(sharesText) ?? 0) > 0
    }

    private var codePlaceholder: String {
        switch account.type {
        case .fundApp: return "基金代码,如 005827"
        case .brokerA: return "股票代码,如 600519 / 000001"
        case .brokerHK: return "港股代码,如 00700"
        case .brokerUS: return "美股代码,如 AAPL"
        case .goldDeposit: return "如 AU9999 或自定义"
        case .goldPhysical: return "如 GOLDBAR_100G"
        default: return "资产代码"
        }
    }

    private var sharesPlaceholder: String {
        account.type.isGold ? "如 30 克" : "如 1234.56 份"
    }

    private var sharesLabel: String {
        account.type.isGold ? "持有克数" : "持有份额/股数"
    }

    private var marketValue: Double {
        let shares = Double(sharesText) ?? 0
        let price = Double(lastPriceText) ?? 0
        return shares * price
    }

    private var costBasis: Double {
        let shares = Double(sharesText) ?? 0
        let cost = Double(avgCostText) ?? 0
        return shares * cost
    }

    private var unrealizedPnL: Double {
        guard costBasis > 0 else { return 0 }
        return marketValue - costBasis
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountTile
                    assetCard
                    positionCard
                    marketValueHighlight
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("添加持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }
            .onChange(of: assetCode) { _, _ in scheduleFetch() }
        }
    }

    private var accountTile: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#5B8FF9").opacity(0.18))
                Image(systemName: account.type.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5B8FF9"))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(account.type.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var assetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资产")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)

            // 代码行
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("代码")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField(codePlaceholder, text: $assetCode)
                        .font(.system(size: 17, weight: .semibold))
                        .autocapitalization(.allCharacters)
                        .focused($focusedField, equals: .code)
                }
                statusBadge
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 3) {
                Text("名称")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField(assetName.isEmpty ? "输入代码后将自动同步" : "", text: $assetName)
                    .font(.system(size: 15))
                    .focused($focusedField, equals: .name)
            }

            Divider().opacity(0.4)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.type.isGold ? "金价 ¥/克" : "当前价")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("输入代码后将自动同步", text: $lastPriceText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .focused($focusedField, equals: .price)
                }
                Spacer()
                if status == .success {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("已同步")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        case .failure:
            Button {
                scheduleFetch()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("重试")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color(hex: "#E89B2A"))
            }
        }
    }

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("持仓信息")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)

            HStack {
                Text(sharesLabel)
                    .font(.system(size: 14))
                Spacer()
                TextField(sharesPlaceholder, text: $sharesText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .focused($focusedField, equals: .shares)
            }
            Divider().opacity(0.4)
            HStack {
                Text("平均成本")
                    .font(.system(size: 14))
                Spacer()
                TextField("", text: $avgCostText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .focused($focusedField, equals: .avgCost)
            }
            Text("可留空 · 留空将以当前价作为成本(浮盈 = 0)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var marketValueHighlight: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Palette.accent.opacity(0.20))
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accentDark)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("预估市值")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(marketValue > 0 ? formatCNY(marketValue) : "¥ — ")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer()

            if costBasis > 0 {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("累计盈亏")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(CurrencyFormatter.signedCNY(unrealizedPnL))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnlColor(unrealizedPnL))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Theme.Palette.accent.opacity(0.16), Theme.Palette.accent.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Palette.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatCNY(_ v: Double) -> String {
        CurrencyFormatter.cnyString(v)
    }

    private func scheduleFetch() {
        fetchTask?.cancel()
        let code = assetCode.trimmingCharacters(in: .whitespaces)
        let minLen = account.type.isGold ? 2 : 4
        guard code.count >= minLen else {
            status = .idle
            return
        }
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await fetchPrice(for: code)
        }
    }

    private func fetchPrice(for codeInput: String) async {
        let code = codeInput.uppercased()
        await MainActor.run { status = .loading }

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
                let c = code.replacingOccurrences(of: ".HK", with: "")
                result = try await PriceService.fetchHKStock(code: c)
            case .brokerUS:
                let c = code.replacingOccurrences(of: ".US", with: "")
                result = try await PriceService.fetchUSStock(symbol: c)
            case .brokerHKUS:
                if code.hasSuffix(".HK") {
                    let c = code.replacingOccurrences(of: ".HK", with: "")
                    result = try await PriceService.fetchHKStock(code: c)
                } else {
                    let c = code.replacingOccurrences(of: ".US", with: "")
                    result = try await PriceService.fetchUSStock(symbol: c)
                }
            case .goldDeposit, .goldPhysical:
                result = try await PriceService.fetchGoldSpotCNYPerGram()
            default:
                await MainActor.run { status = .failure }
                return
            }
            await MainActor.run {
                lastPriceText = String(format: "%.4f", result.price)
                if assetName.trimmingCharacters(in: .whitespaces).isEmpty,
                   let name = result.assetName, !name.isEmpty {
                    assetName = name
                }
                status = .success
            }
        } catch {
            await MainActor.run { status = .failure }
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
        let cost = (Double(avgCostText) ?? 0)
        let effectiveCost = cost > 0 ? cost : lastPrice  // 留空时用当前价
        let pos = Position(
            account: account,
            assetCode: finalCode,
            assetName: assetName.trimmingCharacters(in: .whitespaces),
            shares: Double(sharesText) ?? 0,
            avgCost: effectiveCost,
            lastPrice: lastPrice,
            prevClosePrice: lastPrice,
            weekAgoPrice: lastPrice,
            monthAgoPrice: lastPrice,
            yearStartPrice: lastPrice
        )
        context.insert(pos)
        do {
            try context.save()
            ToastManager.shared.success("已添加持仓「\(pos.assetName)」")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
