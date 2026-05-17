import SwiftUI
import SwiftData

struct AddDCAPlanSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var planName = ""
    @State private var sourceAccountID: UUID?
    @State private var targetAccountID: UUID?
    @State private var assetCode = ""
    @State private var assetName = ""
    @State private var amountText = ""
    @State private var frequency: DCAFrequency = .weekly
    @State private var dayOfWeek: Int = 1     // 1=周一
    @State private var dayOfMonth: Int = 1    // 1-28
    @State private var nextRunDate: Date = Date()
    @State private var didInitDate = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, code, asset, amount
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
                        Divider().opacity(0.4).padding(.leading, 56)
                        amountRow
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
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("新建定投")
                            .font(.system(size: 16, weight: .bold))
                        Text("系统会按日自动执行")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSave ? Theme.Palette.accentDark : .secondary)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Text("完成")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Palette.accentDark)
                    }
                }
            }
            .onAppear {
                if !didInitDate {
                    didInitDate = true
                    recomputeNext()
                }
            }
            .onChange(of: frequency) { _, _ in recomputeNext() }
            .onChange(of: dayOfWeek) { _, _ in recomputeNext() }
            .onChange(of: dayOfMonth) { _, _ in recomputeNext() }
        }
    }

    // MARK: - 计划名称 hero

    private var planNameHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("计划名称")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            TextField("如:每周一定投易方达蓝筹", text: $planName)
                .font(.system(size: 22, weight: .bold))
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

    // MARK: - 通用 section

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
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
            if sourceAccounts.isEmpty {
                Text("请先创建现金/货基账户")
            } else {
                Picker("", selection: $sourceAccountID) {
                    Text("请选择").tag(UUID?.none)
                    ForEach(sourceAccounts) { acc in
                        Text(acc.name).tag(Optional(acc.id))
                    }
                }
            }
        } label: {
            formRow(
                iconName: "wallet.pass.fill",
                iconColor: Color(hex: "#5B8FF9"),
                label: "扣款账户",
                value: selectedSource?.name ?? "请选择",
                placeholder: selectedSource == nil
            )
        }
    }

    private var targetAccountRow: some View {
        Menu {
            if targetAccounts.isEmpty {
                Text("请先创建投资类账户")
            } else {
                Picker("", selection: $targetAccountID) {
                    Text("请选择").tag(UUID?.none)
                    ForEach(targetAccounts) { acc in
                        Text(acc.name).tag(Optional(acc.id))
                    }
                }
            }
        } label: {
            formRow(
                iconName: "chart.pie.fill",
                iconColor: Theme.Palette.accent,
                label: "买入目标",
                value: selectedTarget?.name ?? "请选择",
                placeholder: selectedTarget == nil
            )
        }
    }

    // MARK: - 资产

    private var codeRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "sparkles", color: Color(hex: "#F4B860"))
            Text("代码")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            TextField("005827", text: $assetCode)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .code)
            TextField("资产名称", text: $assetName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 110)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .asset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var amountRow: some View {
        HStack(spacing: 12) {
            iconBadge(iconName: "arrow.down.to.line", color: Color.pnlNegative)
            Text("每次扣款")
                .font(.system(size: 13))
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

    // MARK: - 执行频率

    private var frequencySegmented: some View {
        HStack(spacing: 6) {
            ForEach(DCAFrequency.allCases, id: \.self) { f in
                Button {
                    frequency = f
                } label: {
                    Text(f.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(frequency == f ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(frequency == f
                                      ? Color.primary.opacity(0.92)
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
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { d in
                    Button {
                        dayOfWeek = d
                    } label: {
                        Text("周" + WeekdayPicker.labels[d - 1])
                            .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 12))
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
            iconBadge(iconName: "calendar", color: Color(hex: "#3478F6"))
            Text("下次扣款日")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Spacer(minLength: 0)
            DatePicker(
                "",
                selection: $nextRunDate,
                displayedComponents: .date
            )
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - hint

    private var hintFooter: some View {
        Text("创建后,系统会在每个扣款日自动从扣款账户扣款 + 生成「在途」交易 · T+2 后自动按确认净值入仓 · 不再需要手动确认。")
            .font(.system(size: 11))
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 14, weight: placeholder ? .regular : .semibold))
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
        Image(systemName: iconName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }

    // MARK: - logic

    private func recomputeNext() {
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

        let plan = DCAPlan(
            name: planName.trimmingCharacters(in: .whitespaces),
            sourceAccountID: src.id,
            sourceAccountName: src.name,
            targetAccountID: tgt.id,
            targetAccountName: tgt.name,
            targetAssetCode: assetCode.trimmingCharacters(in: .whitespaces).uppercased(),
            targetAssetName: assetName.trimmingCharacters(in: .whitespaces),
            amount: Double(amountText) ?? 0,
            frequency: frequency,
            nextRunDate: nextRunDate,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth
        )
        context.insert(plan)
        do {
            try context.save()
            ToastManager.shared.success("已创建定投计划")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
