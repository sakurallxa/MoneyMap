import SwiftUI
import SwiftData

struct EditDCAPlanSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    let plan: DCAPlan

    @State private var planName: String
    @State private var sourceAccountID: UUID?
    @State private var targetAccountID: UUID?
    @State private var assetCode: String
    @State private var assetName: String
    @State private var amountText: String
    @State private var feeText: String
    @State private var frequency: DCAFrequency
    @State private var dayOfWeek: Int
    @State private var dayOfMonth: Int
    @State private var nextRunDate: Date
    @State private var userTouchedDate = false
    @State private var assetFetchTask: Task<Void, Never>?
    @State private var assetFetchStatus: AddDCAPlanSheet.FetchStatus = .idle
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, code, asset, amount, fee
    }

    init(plan: DCAPlan) {
        self.plan = plan
        _planName = State(initialValue: plan.name)
        _sourceAccountID = State(initialValue: plan.sourceAccountID)
        _targetAccountID = State(initialValue: plan.targetAccountID)
        _assetCode = State(initialValue: plan.targetAssetCode)
        _assetName = State(initialValue: plan.targetAssetName)
        _amountText = State(initialValue: String(format: "%.2f", plan.amount))
        _feeText = State(initialValue: plan.feeRatePercent > 0 ? String(format: "%.2f", plan.feeRatePercent) : "")
        _frequency = State(initialValue: plan.frequency)
        _dayOfWeek = State(initialValue: max(1, min(7, plan.dayOfWeek)))
        _dayOfMonth = State(initialValue: max(1, min(28, plan.dayOfMonth)))
        _nextRunDate = State(initialValue: plan.nextRunDate)
    }

    private var sourceAccounts: [Account] {
        accounts.filter { $0.type == .cash || $0.type == .moneyFund }
    }

    private var targetAccounts: [Account] {
        accounts.filter { $0.type.isInvestment }
    }

    private var selectedSource: Account? {
        guard let id = sourceAccountID else { return nil }
        return accounts.first { $0.id == id }
    }

    private var selectedTarget: Account? {
        guard let id = targetAccountID else { return nil }
        return accounts.first { $0.id == id }
    }

    private var canSave: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty &&
        sourceAccountID != nil &&
        targetAccountID != nil &&
        !assetCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !assetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    planNameHero
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    section(title: "资金流向") {
                        sourceAccountRow
                        Divider().opacity(0.4).padding(.leading, 56)
                        targetAccountRow
                    }

                    section(title: "资产") {
                        codeRow
                        assetFetchHint
                        Divider().opacity(0.4).padding(.leading, 56)
                        nameRow
                        Divider().opacity(0.4).padding(.leading, 56)
                        amountRow
                        Divider().opacity(0.4).padding(.leading, 56)
                        feeRow
                    }

                    section(title: "执行频率") {
                        frequencySegmented
                        Divider().opacity(0.4)
                        if frequency.needsDayOfWeek {
                            weekdayChips
                            Divider().opacity(0.4)
                        }
                        if frequency.needsDayOfMonth {
                            monthDayPicker
                            Divider().opacity(0.4)
                        }
                        nextRunRow
                    }

                    hintFooter
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 32)
                }
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.Palette.accentDark)
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("编辑定投")
                            .font(Theme.serif(16, weight: .bold))
                        Text("修改后立即生效")
                            .font(Theme.serif(11))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(canSave ? Theme.Palette.accentDark : Theme.Palette.accentDark.opacity(0.35))
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
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
            .onChange(of: frequency) { _, _ in recomputeIfUserDidntOverride() }
            .onChange(of: dayOfWeek) { _, _ in recomputeIfUserDidntOverride() }
            .onChange(of: dayOfMonth) { _, _ in recomputeIfUserDidntOverride() }
            .onChange(of: nextRunDate) { _, _ in
                userTouchedDate = true
            }
            // 自动拉取资产名称(代码 / 目标账户类型 任一变化都重新拉)
            .onChange(of: assetCode) { _, _ in scheduleAssetFetch() }
            .onChange(of: targetAccountID) { _, _ in scheduleAssetFetch() }
        }
    }

    // MARK: - 资产名称自动拉取(P0 hotfix)

    @ViewBuilder
    private var assetFetchBadge: some View {
        switch assetFetchStatus {
        case .idle: EmptyView()
        case .loading:
            ProgressView().scaleEffect(0.7)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Semantic.success)
        case .failure:
            Button { scheduleAssetFetch() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("重试")
                        .font(Theme.serif(11, weight: .semibold))
                }
                .foregroundStyle(Theme.Semantic.warning)
            }
        case .needsTarget:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Semantic.warning)
        }
    }

    @ViewBuilder
    var assetFetchHint: some View {
        switch assetFetchStatus {
        case .failure(let reason):
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text(reason)
                    .font(Theme.serif(11))
            }
            .foregroundStyle(Theme.Semantic.warning)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        case .needsTarget:
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text("请先选择买入目标,再输入代码")
                    .font(Theme.serif(11))
            }
            .foregroundStyle(Theme.Semantic.warning)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        default:
            EmptyView()
        }
    }

    private func scheduleAssetFetch() {
        assetFetchTask?.cancel()
        let raw = assetCode.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else {
            assetFetchStatus = .idle
            return
        }
        guard raw.count >= 2 else {
            assetFetchStatus = .idle
            return
        }
        guard selectedTarget != nil else {
            assetFetchStatus = .needsTarget
            return
        }
        assetFetchTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await fetchAssetName(for: raw)
        }
    }

    private func fetchAssetName(for codeInput: String) async {
        guard let target = selectedTarget else {
            await MainActor.run { assetFetchStatus = .needsTarget }
            return
        }
        let code = codeInput.uppercased()
        await MainActor.run { assetFetchStatus = .loading }
        do {
            // 统一走 QuoteResolver,自带智能容错
            let result = try await QuoteResolver.quote(code: code, accountType: target.type)
            await MainActor.run {
                if let name = result.assetName, !name.isEmpty {
                    if assetName.trimmingCharacters(in: .whitespaces).isEmpty {
                        assetName = name
                    }
                    assetFetchStatus = .success
                } else {
                    assetFetchStatus = .failure("未找到代码「\(code)」")
                }
            }
        } catch {
            await MainActor.run {
                assetFetchStatus = .failure("拉取失败 · 点重试")
            }
        }
    }

    // MARK: - 计划名称 hero

    private var planNameHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("计划名称")
                .font(Theme.serif(11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            TextField("计划名称", text: $planName)
                .font(Theme.serif(22, weight: .bold))
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .name)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    // MARK: - section helper

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.serif(11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 22)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 14)
            .cardElevation()
        }
        .padding(.top, 16)
    }

    // MARK: - 资金流向

    private var sourceAccountRow: some View {
        Menu {
            Picker("", selection: $sourceAccountID) {
                ForEach(sourceAccounts) { acc in
                    Text(acc.name).tag(Optional(acc.id))
                }
            }
        } label: {
            formRow(
                iconName: "wallet.pass.fill",
                iconColor: Theme.Bronze.dark,
                label: "扣款账户",
                value: selectedSource?.name ?? "请选择",
                placeholder: selectedSource == nil
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var targetAccountRow: some View {
        Menu {
            Picker("", selection: $targetAccountID) {
                ForEach(targetAccounts) { acc in
                    Text(acc.name).tag(Optional(acc.id))
                }
            }
        } label: {
            formRow(
                iconName: "chart.pie.fill",
                iconColor: Theme.Bronze.dark,
                label: "买入目标",
                value: selectedTarget?.name ?? "请选择",
                placeholder: selectedTarget == nil
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - 资产

    private var codeRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "sparkles", color: Theme.Bronze.dark)
            Text("代码")
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            TextField("如 005827 / AAPL", text: $assetCode)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .code)
            assetFetchBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var nameRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "tag.fill", color: Theme.Bronze.dark)
            Text("资产名称")
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            TextField("输入代码后将自动同步", text: $assetName)
                .font(Theme.serif(14))
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .asset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var amountRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "arrow.down.to.line", color: Theme.Bronze.dark)
            Text("每次扣款")
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 1) {
                Text("¥")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .focused($focusedField, equals: .amount)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 手续费率(% 单位)
    private var feeRow: some View {
        let rate = max(0, Double(feeText) ?? 0)
        let amount = Double(amountText) ?? 0
        let actual = amount * rate / 100
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                iconBadge(iconName: "yensign.circle", color: Theme.Bronze.dark)
                Text("手续费率")
                    .font(Theme.serif(13))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 1) {
                    TextField("0", text: $feeText)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .fee)
                        .frame(minWidth: 80)
                    Text("%")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .fee }
            }
            if rate > 0 && amount > 0 {
                HStack {
                    Spacer()
                    Text("约 ¥\(String(format: "%.2f", actual))/次")
                        .font(Theme.serif(11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .fee }
    }

    // MARK: - 频率

    private var frequencySegmented: some View {
        HStack(spacing: 6) {
            ForEach(DCAFrequency.allCases, id: \.self) { f in
                Button {
                    frequency = f
                } label: {
                    Text(f.displayName)
                        .font(Theme.serif(12, weight: .semibold))
                        .foregroundStyle(frequency == f ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(frequency == f
                                      ? Theme.Palette.accent
                                      : Color.black.opacity(0.045))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var weekdayChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("星期几扣款")
                .font(Theme.serif(12))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { d in
                    Button {
                        dayOfWeek = d
                    } label: {
                        Text("周" + WeekdayPicker.labels[d - 1])
                            .font(Theme.serif(13, weight: .semibold))
                            .foregroundStyle(dayOfWeek == d ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(dayOfWeek == d ? Theme.Palette.accent : Color.black.opacity(0.045))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var monthDayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每月几号扣款")
                .font(Theme.serif(12))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...28, id: \.self) { d in
                        Button {
                            dayOfMonth = d
                        } label: {
                            Text("\(d)")
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(dayOfMonth == d ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(dayOfMonth == d ? Theme.Palette.accent : Color.black.opacity(0.045))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var nextRunRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "calendar", color: Theme.Bronze.dark)
            Text("下次扣款日")
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Spacer(minLength: 0)
            // 只读展示 — 由频率 + 星期/几号自动算出,不允许手动改
            Text(formattedNextRunDate)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var formattedNextRunDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: nextRunDate)
    }

    // MARK: - hint

    private var hintFooter: some View {
        Text("修改后立即生效,仅影响后续扣款记录生成")
            .font(Theme.serif(11))
            .foregroundStyle(.tertiary)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - shared row

    private func formRow(iconName: String, iconColor: Color, label: String, value: String, placeholder: Bool) -> some View {
        HStack(spacing: 12) {
            iconBadge(iconName: iconName, color: iconColor)
            Text(label)
                .font(Theme.serif(13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(Theme.serif(14, weight: placeholder ? .regular : .semibold))
                .foregroundStyle(placeholder ? .tertiary : .primary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func iconBadge(iconName: String, color: Color) -> some View {
        IconBadge(systemName: iconName, color: color, size: .sm)
    }

    // MARK: - logic

    /// 用户改频率/日期组件时,如果他没有手动碰过 DatePicker,则联动更新下次日期。
    private func recomputeIfUserDidntOverride() {
        if userTouchedDate { return }
        nextRunDate = DCAService.computeNextRun(
            frequency: frequency,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth
        )
    }

    private func save() {
        guard
            let sid = sourceAccountID, let tid = targetAccountID,
            let src = accounts.first(where: { $0.id == sid }),
            let tgt = accounts.first(where: { $0.id == tid })
        else { return }

        plan.name = planName.trimmingCharacters(in: .whitespaces)
        plan.sourceAccountID = src.id
        plan.sourceAccountName = src.name
        plan.targetAccountID = tgt.id
        plan.targetAccountName = tgt.name
        plan.targetAssetCode = assetCode.trimmingCharacters(in: .whitespaces).uppercased()
        plan.targetAssetName = assetName.trimmingCharacters(in: .whitespaces)
        plan.amount = Double(amountText) ?? 0
        plan.feeRatePercent = max(0, Double(feeText) ?? 0)
        plan.feePerRun = 0    // 清零 deprecated 字段,确保不会被任何老代码意外读到
        plan.frequencyRaw = frequency.rawValue
        plan.dayOfWeek = dayOfWeek
        plan.dayOfMonth = dayOfMonth
        plan.nextRunDate = nextRunDate
        do {
            try context.save()
            ToastManager.shared.success("已保存定投计划")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
