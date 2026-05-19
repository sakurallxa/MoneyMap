import SwiftUI
import SwiftData

/// 类型选择 → 表单页 的统一容器。
/// 按 `type` 切换 Hero 卡 + 次要字段 + CTA 文案。
struct TransactionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var positions: [Position]
    let type: TransactionFormType
    let onSave: () -> Void
    /// 来自再平衡 / 调试入口的预填(可选)— 包含 action + assetClass + amount,
    /// 用于自动选中匹配的持仓 + 预填金额,避免用户重复输入。
    var rebalancePrefill: RebalancePrefill? = nil

    @State private var amountText: String = ""
    @State private var sharesText: String = ""
    @State private var priceText: String = ""
    @State private var selectedPositionID: UUID?
    @State private var selectedCashAccountID: UUID?
    @State private var selectedFromAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var newAssetCode: String = ""
    @State private var newAssetName: String = ""
    @State private var selectedTargetAccountID: UUID?    // buyNew 时:买入到哪个投资账户
    @State private var pendingMergePosition: Position?    // P1.3:buyNew 检测到同账户同资产已存在 → 弹合并 alert
    @State private var feeText: String = ""    // 手续费(可选,买入/卖出/...) ;空 / 非数字 → 0
    @State private var dividendPerShare: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var fetchTask: Task<Void, Never>? = nil
    @State private var isFetching = false
    @State private var lockedField: LockedTriangleField = .amount
    @FocusState private var focusedField: TriangleField?

    enum LockedTriangleField {
        case amount, shares, price
    }
    enum TriangleField: Hashable {
        case amount, shares, price
    }

    private var cashAccounts: [Account] {
        accounts.filter { $0.type == .cash || $0.type == .moneyFund }
    }
    private var investmentAccounts: [Account] {
        accounts.filter { $0.type.isInvestment }
    }
    private var selectedPosition: Position? {
        positions.first { $0.id == selectedPositionID }
    }
    private var selectedCashAccount: Account? {
        accounts.first { $0.id == selectedCashAccountID }
    }
    /// buyNew 选中的投资账户(目标)
    private var selectedTargetAccount: Account? {
        accounts.first { $0.id == selectedTargetAccountID }
    }
    private var fromAccount: Account? {
        accounts.first { $0.id == selectedFromAccountID }
    }
    private var toAccount: Account? {
        accounts.first { $0.id == selectedToAccountID }
    }

    private var amountValue: Double { Double(amountText) ?? 0 }
    private var priceValue: Double { Double(priceText) ?? 0 }
    private var sharesValue: Double { Double(sharesText) ?? 0 }
    /// 手续费率(% 单位)— 空白 / 非数字 / 负数 一律视为 0
    /// 例如:用户输入 0.15 表示 0.15%
    private var feeRateValue: Double { max(0, Double(feeText) ?? 0) }
    /// 根据金额和费率算出实际手续费金额(¥)
    /// fee = amount × rate / 100
    private var actualFee: Double { amountValue * feeRateValue / 100 }
    /// 该交易类型是否支持手续费
    private var supportsFee: Bool {
        switch type {
        case .buyExisting, .buyNew, .sell: return true
        case .dividend, .deposit, .withdraw, .transfer: return false
        }
    }

    /// 校验失败时的原因 — UI 可以提示用户具体哪里不通过(P0 资金安全)
    private var validationError: String? {
        guard amountValue > 0 else { return "请输入金额" }
        switch type {
        case .buyExisting:
            guard let pos = selectedPosition else { return "请选择持仓" }
            guard let cash = selectedCashAccount else { return "请选择扣款账户" }
            if priceValue <= 0 { return "请输入买入价" }
            if sharesValue <= 0 { return "请输入买入份额" }
            if cash.cashBalance < amountValue + actualFee {
                return "扣款账户余额不足(剩 ¥\(String(format: "%.2f", cash.cashBalance)))"
            }
            _ = pos  // silence unused
            return nil
        case .sell:
            guard let pos = selectedPosition else { return "请选择持仓" }
            guard selectedCashAccount != nil else { return "请选择收款账户" }
            if priceValue <= 0 { return "请输入卖出价" }
            if sharesValue <= 0 { return "请输入卖出份额" }
            if sharesValue > pos.shares {
                return "超过当前持有 \(String(format: "%.2f", pos.shares)) 份"
            }
            // M2:手续费不能高于或等于卖出金额(否则到账 ≤0,卖出反而扣钱)
            if actualFee >= amountValue {
                return "手续费(¥\(String(format: "%.2f", actualFee)))不能超过卖出金额"
            }
            return nil
        case .dividend:
            // 分红只用 amountValue 落账,不要求 price/shares > 0
            guard selectedPosition != nil else { return "请选择持仓" }
            guard selectedCashAccount != nil else { return "请选择收款账户" }
            return nil
        case .buyNew:
            if newAssetCode.trimmingCharacters(in: .whitespaces).isEmpty { return "请输入资产代码" }
            if newAssetName.trimmingCharacters(in: .whitespaces).isEmpty { return "请输入资产名称" }
            guard let cash = selectedCashAccount else { return "请选择扣款账户" }
            if selectedTargetAccount == nil { return "请选择买入到哪个账户" }
            if priceValue <= 0 { return "请输入买入价" }
            if sharesValue <= 0 { return "请输入买入份额" }
            if cash.cashBalance < amountValue + actualFee {
                return "扣款账户余额不足(剩 ¥\(String(format: "%.2f", cash.cashBalance)))"
            }
            return nil
        case .deposit:
            guard selectedCashAccount != nil else { return "请选择收款账户" }
            return nil
        case .withdraw:
            guard let cash = selectedCashAccount else { return "请选择出账账户" }
            if cash.cashBalance < amountValue {
                return "账户余额不足(剩 ¥\(String(format: "%.2f", cash.cashBalance)))"
            }
            return nil
        case .transfer:
            guard let from = fromAccount else { return "请选择转出账户" }
            guard let to = toAccount else { return "请选择转入账户" }
            if from.id == to.id { return "转入转出不能是同一账户" }
            if from.cashBalance < amountValue {
                return "转出账户余额不足(剩 ¥\(String(format: "%.2f", from.cashBalance)))"
            }
            return nil
        }
    }

    private var canSubmit: Bool { validationError == nil }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 18) {
                    AmountInputView(
                        type: type,
                        amountText: $amountText
                    )
                    .padding(.top, 20)

                    typeHero

                    fundFlowCard

                    secondaryFields

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 14)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())

            stickyCTA
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(type.color.opacity(0.22))
                            .frame(width: 22, height: 22)
                        Image(systemName: type.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(type.color)
                    }
                    Text(type.title)
                        .font(Theme.serif(15, weight: .semibold))
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Text("完成")
                            .font(Theme.serif(15, weight: .bold))
                            .foregroundStyle(Theme.Palette.accentDark)
                    }
                }
            }
        }
        .onAppear {
            autoSelectDefaults()
        }
        .onChange(of: newAssetCode) { _, _ in
            if type == .buyNew {
                // 代码变更:清空上次的名称和价格,避免新代码 fetch 失败时残留旧资产
                newAssetName = ""
                priceText = ""
                scheduleFetch()
            }
        }
        .onChange(of: selectedPositionID) { _, _ in
            if let pos = selectedPosition, priceText.isEmpty {
                priceText = String(format: "%.4f", pos.lastPrice)
                if amountValue > 0, priceValue > 0 {
                    sharesText = String(format: "%.4f", amountValue / priceValue)
                }
            }
        }
        // P1.3:buyNew 检测到同账户同资产已存在 → 弹合并 alert
        .alert(
            "已有相同持仓",
            isPresented: Binding(
                get: { pendingMergePosition != nil },
                set: { if !$0 { pendingMergePosition = nil } }
            ),
            presenting: pendingMergePosition
        ) { existing in
            Button("合并加仓") {
                performBuyNewMerge(into: existing)
                pendingMergePosition = nil
            }
            Button("取消", role: .cancel) {
                pendingMergePosition = nil
            }
        } message: { existing in
            Text("「\(existing.assetName)」(\(existing.assetCode))已经在该账户存在。是否合并为加仓?")
        }
    }

    private func autoSelectDefaults() {
        // 再平衡 prefill:优先匹配 assetClass 的持仓,并预填金额
        if let p = rebalancePrefill {
            if amountText.isEmpty {
                amountText = String(format: "%.2f", p.amount)
            }
            if selectedPositionID == nil {
                let match = positions.first { $0.assetClass == p.assetClass }
                if let m = match {
                    selectedPositionID = m.id
                    if priceText.isEmpty {
                        priceText = String(format: "%.4f", m.lastPrice)
                    }
                }
            }
        }
        switch type {
        case .buyExisting, .sell, .dividend:
            if selectedPositionID == nil, let first = positions.first {
                selectedPositionID = first.id
                priceText = String(format: "%.4f", first.lastPrice)
            }
            if selectedCashAccountID == nil, let cash = cashAccounts.first {
                selectedCashAccountID = cash.id
            }
        case .buyNew:
            if selectedCashAccountID == nil, let cash = cashAccounts.first {
                selectedCashAccountID = cash.id
            }
        case .deposit, .withdraw:
            if selectedCashAccountID == nil, let cash = cashAccounts.first {
                selectedCashAccountID = cash.id
            }
        case .transfer:
            if selectedFromAccountID == nil, let from = cashAccounts.first {
                selectedFromAccountID = from.id
            }
            if selectedToAccountID == nil, let to = cashAccounts.dropFirst().first ?? cashAccounts.first {
                selectedToAccountID = to.id
            }
        }
    }

    private func scheduleFetch() {
        fetchTask?.cancel()
        let code = newAssetCode.trimmingCharacters(in: .whitespaces)
        guard code.count >= 3 else { return }
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await fetchPrice(for: code)
        }
    }

    private func fetchPrice(for codeInput: String) async {
        await MainActor.run { isFetching = true }
        defer { Task { @MainActor in isFetching = false } }

        let code = codeInput.uppercased().trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }

        if let result = await dispatchFetch(code: code) {
            await MainActor.run {
                priceText = String(format: "%.4f", result.price)
                if newAssetName.trimmingCharacters(in: .whitespaces).isEmpty,
                   let n = result.assetName, !n.isEmpty {
                    newAssetName = n
                }
            }
        } else {
            await MainActor.run {
                // 用 .info 而非 .error — 这是验证类轻提示,需要自动消失。
                ToastManager.shared.info("未找到代码「\(code)」",
                                         subtitle: "可手动填写资产名称和价格")
            }
        }
    }

    /// 根据代码格式智能 fallback 多个行情源,任一成功即返回。
    /// 规则:
    ///   - 6 位纯数字:基金 → A 股
    ///   - 5 位纯数字 / 含 ".HK":港股
    ///   - 含 ".US" / 纯字母:美股
    ///   - 包含已知黄金代码:黄金现货
    private func dispatchFetch(code: String) async -> PriceQuoteResult? {
        debugLog("🔍 [Fetch] dispatch start code=\(code)")

        if GoldRecognizer.isGoldAssetCode(code) {
            if let r = await tryFetch(tag: "gold spot", op: { try await PriceService.fetchGoldSpotCNYPerGram() }) { return r }
        }
        if code.hasSuffix(".HK") {
            let c = code.replacingOccurrences(of: ".HK", with: "")
            if let r = await tryFetch(tag: "HK \(c)", op: { try await PriceService.fetchHKStock(code: c) }) { return r }
        }
        if code.hasSuffix(".US") {
            let c = code.replacingOccurrences(of: ".US", with: "")
            if let r = await tryFetch(tag: "US \(c)", op: { try await PriceService.fetchUSStock(symbol: c) }) { return r }
        }
        if code.count == 5, code.allSatisfy({ $0.isNumber }) {
            if let r = await tryFetch(tag: "HK 5-digit \(code)", op: { try await PriceService.fetchHKStock(code: code) }) { return r }
        }
        if code.count == 6, code.allSatisfy({ $0.isNumber }) {
            if let r = await tryFetch(tag: "Fund \(code)", op: { try await PriceService.fetchFundNAV(code: code) }) { return r }
            if let r = await tryFetch(tag: "A-share \(code)", op: { try await PriceService.fetchAShare(code: code) }) { return r }
        }
        if code.allSatisfy({ $0.isLetter }) {
            if let r = await tryFetch(tag: "US letters \(code)", op: { try await PriceService.fetchUSStock(symbol: code) }) { return r }
        }
        // 兜底:依次试所有源
        if let r = await tryFetch(tag: "fallback Fund", op: { try await PriceService.fetchFundNAV(code: code) }) { return r }
        if let r = await tryFetch(tag: "fallback A-share", op: { try await PriceService.fetchAShare(code: code) }) { return r }
        if let r = await tryFetch(tag: "fallback HK", op: { try await PriceService.fetchHKStock(code: code) }) { return r }
        if let r = await tryFetch(tag: "fallback US", op: { try await PriceService.fetchUSStock(symbol: code) }) { return r }

        debugLog("🔍 [Fetch] all sources failed for code=\(code)")
        return nil
    }

    /// 单源试探 + 日志 — 成功打印 ✅,失败打印 ❌ 及错误。
    private func tryFetch(tag: String, op: () async throws -> PriceQuoteResult) async -> PriceQuoteResult? {
        do {
            let r = try await op()
            debugLog("✅ [Fetch:\(tag)] price=\(r.price) name=\(r.assetName ?? "-")")
            return r
        } catch {
            debugLog("❌ [Fetch:\(tag)] error=\(error)")
            return nil
        }
    }


    @ViewBuilder
    private var typeHero: some View {
        switch type {
        case .buyExisting, .sell, .dividend:
            existingAssetHero
        case .buyNew:
            newAssetHero
        case .deposit, .withdraw:
            accountHero
        case .transfer:
            transferHero
        }
    }

    /// 资金来源 / 资金去向卡 — 在 4 类资产交易表单中统一展示现金账户选择器。
    /// - buyExisting / buyNew: 「资金来源」(钱从哪个现金账户出)
    /// - sell / dividend:     「资金去向」(钱到哪个现金账户)
    /// - deposit/withdraw/transfer 已自带账户选择,这里不渲染
    @ViewBuilder
    private var fundFlowCard: some View {
        switch type {
        case .buyExisting, .buyNew:
            cashAccountFlowRow(label: "资金来源", prefix: "从")
        case .sell, .dividend:
            cashAccountFlowRow(label: "资金去向", prefix: "到")
        case .deposit, .withdraw, .transfer:
            EmptyView()
        }
    }

    private func cashAccountFlowRow(label: String, prefix: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#5B8FF9").opacity(0.16))
                Image(systemName: selectedCashAccount?.type.iconName ?? "creditcard.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5B8FF9"))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.serif(11))
                    .foregroundStyle(.tertiary)
                Text("\(prefix) \(selectedCashAccount?.name ?? "请选择")")
                    .font(Theme.serif(14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Menu {
                ForEach(cashAccounts) { acc in
                    Button(acc.name) { selectedCashAccountID = acc.id }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("切换")
                        .font(Theme.serif(12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.Palette.accentDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Theme.Palette.accent.opacity(0.12))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var existingAssetHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let pos = selectedPosition {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Palette.accent.opacity(0.15))
                        Text(String(pos.assetName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.Palette.accentDark)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pos.assetName)
                            .font(Theme.serif(15, weight: .semibold))
                        HStack(spacing: 6) {
                            Text(pos.assetCode)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(pos.account?.name ?? "")
                                .font(Theme.serif(11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        // 「现价 + 份额」合并到信息区(灰字),清晰传达"持有信息"
                        HStack(spacing: 6) {
                            Text(String(format: "现价 ¥%.4f", pos.lastPrice))
                            Text("·")
                            Text(String(format: "持 %.2f 份", pos.shares))
                                .monospacedDigit()
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    // 「切换」独立操作 — chevron + 文字
                    Menu {
                        ForEach(positions) { p in
                            Button(p.assetName) {
                                selectedPositionID = p.id
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("切换")
                                .font(Theme.serif(12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Palette.accentDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Theme.Palette.accent.opacity(0.12))
                        )
                    }
                }
                .padding(16)
            } else {
                Text("请先添加持仓")
                    .font(Theme.serif(15))
                    .foregroundStyle(.tertiary)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var newAssetHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            // P1:目标投资账户选择(取代之前的 investmentAccounts.first 默认)
            targetAccountPicker

            Divider().opacity(0.4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("资产代码")
                        .font(Theme.serif(11, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(.tertiary)
                    TextField("如 005827 / AAPL", text: $newAssetCode)
                        .font(.system(size: 22, weight: .bold))
                        .autocapitalization(.allCharacters)
                }
                Spacer()
                if isFetching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            TextField("资产名称(输入代码后将自动同步)", text: $newAssetName)
                .font(Theme.serif(14))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    /// buyNew 专属:选择买入到哪个投资账户
    private var targetAccountPicker: some View {
        HStack(spacing: 10) {
            Text("买入到")
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            Menu {
                if investmentAccounts.isEmpty {
                    Text("请先创建一个投资类账户")
                } else {
                    Picker("", selection: $selectedTargetAccountID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(investmentAccounts) { acc in
                            Text("\(acc.name) · \(acc.type.displayName)").tag(Optional(acc.id))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedTargetAccount.map { "\($0.name) · \($0.type.displayName)" } ?? "请选择")
                        .font(Theme.serif(14, weight: selectedTargetAccount == nil ? .regular : .semibold))
                        .foregroundStyle(selectedTargetAccount == nil ? .tertiary : .primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .tint(.primary)
        }
    }

    private var accountHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let acc = selectedCashAccount {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(type.color.opacity(0.15))
                        Image(systemName: acc.type.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(type.color)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(acc.name)
                            .font(Theme.serif(15, weight: .semibold))
                        Text(String(format: "余额 %@%.2f", acc.currency.symbol, acc.cashBalance))
                            .font(Theme.serif(11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        ForEach(cashAccounts) { a in
                            Button(a.name) { selectedCashAccountID = a.id }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var transferHero: some View {
        VStack(spacing: 0) {
            transferAccountLine(label: "从", account: fromAccount, onTap: {})

            ZStack {
                Divider().opacity(0.5)
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(6)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .padding(.vertical, 4)

            transferAccountLine(label: "到", account: toAccount, onTap: {})
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func transferAccountLine(label: String, account: Account?, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(Theme.serif(13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .leading)

            Menu {
                ForEach(cashAccounts) { acc in
                    Button(acc.name) {
                        if label == "从" {
                            selectedFromAccountID = acc.id
                        } else {
                            selectedToAccountID = acc.id
                        }
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((label == "从" ? Color.pnlNegative : Color.pnlPositive).opacity(0.14))
                        Image(systemName: account?.type.iconName ?? "creditcard.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(label == "从" ? Color.pnlNegative : Color.pnlPositive)
                    }
                    .frame(width: 32, height: 32)

                    if let account {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(Theme.serif(14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(String(format: "余额 %@%.2f", account.currency.symbol, account.cashBalance))
                                .font(Theme.serif(11))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("请选择")
                            .font(Theme.serif(14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.accentDark)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var secondaryFields: some View {
        VStack(spacing: 0) {
            switch type {
            case .buyExisting, .sell:
                triangleCard
                Divider().opacity(0.4).padding(.leading, 18)
                feeField
                Divider().opacity(0.4).padding(.leading, 18)
                dateField
                Divider().opacity(0.4).padding(.leading, 18)
                noteField
            case .buyNew:
                triangleCard
                Divider().opacity(0.4).padding(.leading, 18)
                feeField
                Divider().opacity(0.4).padding(.leading, 18)
                dateField
                Divider().opacity(0.4).padding(.leading, 18)
                noteField
            case .dividend:
                singleFieldRow(label: "每股分红", value: $dividendPerShare, suffix: "¥/份", placeholder: "0.0000")
                Divider().opacity(0.4).padding(.leading, 18)
                dateField
                Divider().opacity(0.4).padding(.leading, 18)
                noteField
            case .deposit, .withdraw, .transfer:
                dateField
                Divider().opacity(0.4).padding(.leading, 18)
                noteField
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    /// 手续费率输入行 — 仅买入/卖出可见,百分比单位,默认 0 选填
    /// 实际手续费 = 金额 × 费率 / 100,在保存时计算成绝对值写入交易记录
    private var feeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("手续费率")
                    .font(Theme.serif(14))
                    .frame(width: 78, alignment: .leading)
                Spacer(minLength: 0)
                TextField("0", text: $feeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            if feeRateValue > 0 && amountValue > 0 {
                HStack {
                    Spacer()
                    Text("约 ¥\(String(format: "%.2f", actualFee))")
                        .font(Theme.serif(11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 三角联动卡:金额 / 份额 / 价格 三选一手动,其他自动重算
    private var triangleCard: some View {
        VStack(spacing: 0) {
            triangleRow(
                field: .amount,
                label: "金额",
                text: $amountText,
                suffix: "¥",
                placeholder: "0.00",
                hint: "金额 = 份额 × 当前价"
            )
            Divider().opacity(0.4).padding(.leading, 18)
            triangleRow(
                field: .shares,
                label: "份额",
                text: $sharesText,
                suffix: "份",
                placeholder: "0.00",
                hint: "份额 = 金额 ÷ 当前价"
            )
            Divider().opacity(0.4).padding(.leading, 18)
            triangleRow(
                field: .price,
                label: "当前价",
                text: $priceText,
                suffix: "¥/份",
                placeholder: "0.0000",
                hint: "自动从行情同步 · 可手动输入"
            )
        }
    }

    private func triangleRow(field: TriangleField, label: String, text: Binding<String>, suffix: String, placeholder: String, hint: String) -> some View {
        let locked = isLocked(field)
        return HStack(alignment: .center, spacing: 10) {
            // accent 左竖条 (仅 locked)
            Rectangle()
                .fill(locked ? Theme.Palette.accent : Color.clear)
                .frame(width: 3, height: 36)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(locked ? .primary : .secondary)
                    if locked {
                        Text("手动")
                            .font(Theme.serif(9, weight: .bold))
                            .foregroundStyle(Theme.Palette.accentDark)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.Palette.accent.opacity(0.18))
                            .clipShape(Capsule())
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8, weight: .bold))
                            Text("自动")
                                .font(Theme.serif(9, weight: .bold))
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                Text(hint)
                    .font(Theme.serif(10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 1) {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(locked ? .primary : .secondary)
                    .focused($focusedField, equals: field)
                    .onChange(of: text.wrappedValue) { _, _ in
                        if focusedField == field {
                            handleTriangleChange(field: field)
                        }
                    }
                    .onTapGesture {
                        setLocked(field)
                    }
                Text(suffix)
                    .font(Theme.serif(11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(locked ? Theme.Palette.accent.opacity(0.05) : Color.clear)
    }

    private func singleFieldRow(label: String, value: Binding<String>, suffix: String, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.serif(14))
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
            Text(suffix)
                .font(Theme.serif(12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func isLocked(_ field: TriangleField) -> Bool {
        switch (lockedField, field) {
        case (.amount, .amount), (.shares, .shares), (.price, .price): return true
        default: return false
        }
    }

    private func setLocked(_ field: TriangleField) {
        switch field {
        case .amount: lockedField = .amount
        case .shares: lockedField = .shares
        case .price: lockedField = .price
        }
    }

    /// 三角联动:lockedField 不变,其他两个 try recompute
    private func handleTriangleChange(field: TriangleField) {
        setLocked(field)
        let amount = Double(amountText) ?? 0
        let shares = Double(sharesText) ?? 0
        let price = Double(priceText) ?? 0
        switch field {
        case .amount:
            // 用户改了金额:有 price → 重算 shares;否则若有 shares → 重算 price
            if price > 0 {
                sharesText = String(format: "%.4f", amount / price)
            } else if shares > 0 && amount > 0 {
                priceText = String(format: "%.4f", amount / shares)
            }
        case .shares:
            if price > 0 {
                amountText = String(format: "%.2f", shares * price)
            } else if amount > 0 && shares > 0 {
                priceText = String(format: "%.4f", amount / shares)
            }
        case .price:
            // 用户改了价格:优先保留份额,重算金额;否则保留金额,重算份额
            if shares > 0 {
                amountText = String(format: "%.2f", shares * price)
            } else if amount > 0 && price > 0 {
                sharesText = String(format: "%.4f", amount / price)
            }
        }
    }

    private var dateField: some View {
        HStack {
            Text("交易日期")
                .font(Theme.serif(14))
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var noteField: some View {
        HStack {
            Text("备注")
                .font(Theme.serif(14))
            Spacer()
            TextField("可空", text: $note)
                .multilineTextAlignment(.trailing)
                .font(Theme.serif(14))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.Palette.pageBgWarm.opacity(0), Theme.Palette.pageBgWarm],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

            // P0:不通过时显式提示原因,而不是让用户对着灰按钮抓瞎
            if let reason = validationError, !amountText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text(reason)
                        .font(Theme.serif(12))
                }
                .foregroundStyle(Theme.Semantic.warning)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }

            Button {
                save()
            } label: {
                Text(ctaText)
                    .font(Theme.serif(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(canSubmit ? type.color : type.color.opacity(0.45))
                    )
                    .shadow(color: type.color.opacity(canSubmit ? 0.34 : 0), radius: 22, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
            .background(Theme.Palette.pageBgWarm)
        }
    }

    private var ctaText: String {
        let prefix: String
        switch type {
        case .buyExisting: prefix = "确认加仓"
        case .buyNew: prefix = "确认首次买入"
        case .sell: prefix = "确认卖出"
        case .dividend: prefix = "记一笔分红"
        case .deposit: prefix = "确认入金"
        case .withdraw: prefix = "确认出金"
        case .transfer: prefix = "确认转账"
        }
        let amt = amountValue
        return prefix + " · ¥\(formatNumber(amt))"
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "0.00"
    }

    private func save() {
        let now = date
        switch type {
        case .buyExisting:
            guard let pos = selectedPosition,
                  let cash = selectedCashAccount,
                  let posAcc = pos.account else { return }
            let fee = actualFee
            let cashBefore = cash.cashBalance
            cash.cashBalance -= (amountValue + fee)    // 本金 + 手续费一并从现金扣
            cash.updatedAt = now
            let newTotal = pos.shares + sharesValue
            // avgCost 含手续费 — (累计成本 + 本次金额 + 本次手续费) / 新份额
            pos.avgCost = newTotal > 0 ? (pos.totalCost + amountValue + fee) / newTotal : 0
            pos.shares = newTotal
            pos.lastPrice = priceValue
            pos.updatedAt = now

            let tx = TransactionRecord(
                tradeDate: now,
                type: pos.assetClass == .gold || pos.assetClass == .fund ? .buyFund : .buyStock,
                status: .completed,
                fromAccountID: cash.id, toAccountID: posAcc.id,
                fromAccountName: cash.name, toAccountName: posAcc.name,
                assetCode: pos.assetCode, assetName: pos.assetName,
                amount: amountValue, shares: sharesValue, price: priceValue,
                fee: fee,
                note: note,
                sourceBalanceBefore: cashBefore, sourceBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .buyNew:
            // P1:目标账户从用户选择拿,不再默认 investmentAccounts.first
            guard let cash = selectedCashAccount,
                  let target = selectedTargetAccount else { return }
            let code = newAssetCode.trimmingCharacters(in: .whitespaces).uppercased()
            // P1.3:重复持仓检测 — 同账户 + 同 normalized assetCode 已存在 → 弹合并 alert,不写入
            if let existing = positions.first(where: {
                $0.account?.id == target.id && $0.assetCode.uppercased() == code
            }) {
                pendingMergePosition = existing
                return
            }
            let fee = actualFee
            let cashBefore = cash.cashBalance
            cash.cashBalance -= (amountValue + fee)    // 本金 + 手续费一并从现金扣
            cash.updatedAt = now
            // avgCost 含手续费 — 首次建仓 avgCost = (本金 + 手续费) / 份额
            let firstAvgCost = sharesValue > 0 ? (amountValue + fee) / sharesValue : priceValue
            let pos = Position(
                account: target,
                assetCode: code,
                assetName: newAssetName.trimmingCharacters(in: .whitespaces),
                shares: sharesValue, avgCost: firstAvgCost, lastPrice: priceValue,
                prevClosePrice: priceValue, weekAgoPrice: priceValue,
                monthAgoPrice: priceValue, yearStartPrice: priceValue
            )
            context.insert(pos)
            // 根据目标账户类型派生 TransactionType
            let txType: TransactionType = {
                switch target.type {
                case .fundApp, .moneyFund:                  return .buyFund
                case .brokerA, .brokerHK, .brokerUS, .brokerHKUS: return .buyStock
                case .goldDeposit, .goldPhysical:           return .buyFund
                default:                                     return .buyFund
                }
            }()
            let tx = TransactionRecord(
                tradeDate: now,
                type: txType,
                status: .completed,
                fromAccountID: cash.id, toAccountID: target.id,
                fromAccountName: cash.name, toAccountName: target.name,
                assetCode: code, assetName: pos.assetName,
                amount: amountValue, shares: sharesValue, price: priceValue,
                fee: fee,
                note: note,
                sourceBalanceBefore: cashBefore, sourceBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .sell:
            guard let pos = selectedPosition,
                  let cash = selectedCashAccount,
                  let posAcc = pos.account else { return }
            let fee = actualFee
            let cashBefore = cash.cashBalance
            cash.cashBalance += (amountValue - fee)    // 到账金额 = 卖出金额 - 手续费
            cash.updatedAt = now
            // canSubmit 已经把关 sharesValue <= pos.shares,这里不再静默 clamp
            pos.shares = pos.shares - sharesValue
            // 卖出时 avgCost 不变(只反映"剩余持仓的历史平均成本")
            pos.lastPrice = priceValue
            pos.updatedAt = now
            let tx = TransactionRecord(
                tradeDate: now,
                type: pos.assetClass == .gold || pos.assetClass == .fund ? .sellFund : .sellStock,
                status: .completed,
                fromAccountID: posAcc.id, toAccountID: cash.id,
                fromAccountName: posAcc.name, toAccountName: cash.name,
                assetCode: pos.assetCode, assetName: pos.assetName,
                amount: amountValue, shares: sharesValue, price: priceValue,
                fee: fee,
                note: note,
                targetBalanceBefore: cashBefore, targetBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .dividend:
            guard let pos = selectedPosition,
                  let cash = selectedCashAccount else { return }
            let cashBefore = cash.cashBalance
            cash.cashBalance += amountValue
            cash.updatedAt = now
            let tx = TransactionRecord(
                tradeDate: now,
                type: .dividend,
                status: .completed,
                toAccountID: cash.id,
                toAccountName: cash.name,
                assetCode: pos.assetCode, assetName: pos.assetName,
                amount: amountValue,
                note: note,
                targetBalanceBefore: cashBefore, targetBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .deposit:
            guard let cash = selectedCashAccount else { return }
            let cashBefore = cash.cashBalance
            cash.cashBalance += amountValue
            cash.updatedAt = now
            let tx = TransactionRecord(
                tradeDate: now,
                type: .deposit, status: .completed,
                toAccountID: cash.id, toAccountName: cash.name,
                amount: amountValue,
                note: note,
                targetBalanceBefore: cashBefore, targetBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .withdraw:
            guard let cash = selectedCashAccount else { return }
            let cashBefore = cash.cashBalance
            cash.cashBalance -= amountValue
            cash.updatedAt = now
            let tx = TransactionRecord(
                tradeDate: now,
                type: .withdraw, status: .completed,
                fromAccountID: cash.id, fromAccountName: cash.name,
                amount: amountValue,
                note: note,
                sourceBalanceBefore: cashBefore, sourceBalanceAfter: cash.cashBalance
            )
            context.insert(tx)

        case .transfer:
            guard let from = fromAccount, let to = toAccount, from.id != to.id else { return }
            let fromBefore = from.cashBalance
            let toBefore = to.cashBalance
            from.cashBalance -= amountValue
            to.cashBalance += amountValue
            from.updatedAt = now
            to.updatedAt = now
            let tx = TransactionRecord(
                tradeDate: now,
                type: .transfer, status: .completed,
                fromAccountID: from.id, toAccountID: to.id,
                fromAccountName: from.name, toAccountName: to.name,
                amount: amountValue,
                note: note,
                sourceBalanceBefore: fromBefore, sourceBalanceAfter: from.cashBalance,
                targetBalanceBefore: toBefore, targetBalanceAfter: to.cashBalance
            )
            context.insert(tx)
        }
        do {
            try context.save()
            SnapshotService.recordToday(context: context)
            ToastManager.shared.success(savedToastTitle)
            onSave()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }

    /// P1.3:buyNew 检测到已有相同持仓时,用户在 alert 选「合并加仓」后调用。
    /// 复用 buyExisting 的加权重算公式;仍然写一条买入交易记录,保证流水完整。
    private func performBuyNewMerge(into existing: Position) {
        let now = date
        guard let cash = selectedCashAccount,
              let posAcc = existing.account else { return }
        let fee = actualFee
        let cashBefore = cash.cashBalance
        cash.cashBalance -= (amountValue + fee)
        cash.updatedAt = now

        let newTotal = existing.shares + sharesValue
        // avgCost 含手续费
        existing.avgCost = newTotal > 0 ? (existing.totalCost + amountValue + fee) / newTotal : 0
        existing.shares = newTotal
        existing.lastPrice = priceValue
        existing.updatedAt = now

        let txType: TransactionType = (existing.assetClass == .gold || existing.assetClass == .fund) ? .buyFund : .buyStock
        let tx = TransactionRecord(
            tradeDate: now,
            type: txType,
            status: .completed,
            fromAccountID: cash.id, toAccountID: posAcc.id,
            fromAccountName: cash.name, toAccountName: posAcc.name,
            assetCode: existing.assetCode, assetName: existing.assetName,
            amount: amountValue, shares: sharesValue, price: priceValue,
            fee: fee,
            note: note,
            sourceBalanceBefore: cashBefore, sourceBalanceAfter: cash.cashBalance
        )
        context.insert(tx)
        do {
            try context.save()
            SnapshotService.recordToday(context: context)
            ToastManager.shared.success("已合并加仓")
            onSave()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }

    private var savedToastTitle: String {
        switch type {
        case .buyExisting: return "已加仓"
        case .buyNew: return "已建仓"
        case .sell: return "已卖出"
        case .dividend: return "已记一笔分红"
        case .deposit: return "已入金"
        case .withdraw: return "已出金"
        case .transfer: return "已转账"
        }
    }
}
