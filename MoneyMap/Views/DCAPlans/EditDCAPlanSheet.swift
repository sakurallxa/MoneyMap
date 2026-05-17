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
    @State private var frequency: DCAFrequency
    @State private var dayOfWeek: Int
    @State private var dayOfMonth: Int
    @State private var nextRunDate: Date
    @State private var userTouchedDate = false

    init(plan: DCAPlan) {
        self.plan = plan
        _planName = State(initialValue: plan.name)
        _sourceAccountID = State(initialValue: plan.sourceAccountID)
        _targetAccountID = State(initialValue: plan.targetAccountID)
        _assetCode = State(initialValue: plan.targetAssetCode)
        _assetName = State(initialValue: plan.targetAssetName)
        _amountText = State(initialValue: String(format: "%.2f", plan.amount))
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
            Form {
                Section("计划名称") {
                    TextField("名称", text: $planName)
                }

                Section("扣款来源") {
                    Picker("扣款账户", selection: $sourceAccountID) {
                        ForEach(sourceAccounts) { acc in
                            Text(acc.name).tag(Optional(acc.id))
                        }
                    }
                }

                Section("买入目标") {
                    Picker("目标账户", selection: $targetAccountID) {
                        ForEach(targetAccounts) { acc in
                            Text(acc.name).tag(Optional(acc.id))
                        }
                    }
                    TextField("资产代码", text: $assetCode)
                        .autocapitalization(.allCharacters)
                    TextField("资产名称", text: $assetName)
                }

                Section("定投设置") {
                    HStack {
                        Text("每次扣款")
                        Spacer()
                        HStack(spacing: 1) {
                            Text("¥")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                                .fixedSize()
                        }
                    }
                    Picker("频率", selection: $frequency) {
                        ForEach(DCAFrequency.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    if frequency.needsDayOfWeek {
                        weekdaySegmented
                    }
                    if frequency.needsDayOfMonth {
                        monthDayPicker
                    }
                    DatePicker("下次扣款日", selection: $nextRunDate, displayedComponents: .date)
                        .onChange(of: nextRunDate) { _, _ in
                            userTouchedDate = true
                        }
                }
            }
            .navigationTitle("编辑定投")
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
            .onChange(of: frequency) { _, _ in recomputeIfUserDidntOverride() }
            .onChange(of: dayOfWeek) { _, _ in recomputeIfUserDidntOverride() }
            .onChange(of: dayOfMonth) { _, _ in recomputeIfUserDidntOverride() }
        }
    }

    private var weekdaySegmented: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("星期几扣款")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("星期", selection: $dayOfWeek) {
                ForEach(1...7, id: \.self) { d in
                    Text(WeekdayPicker.labels[d - 1]).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var monthDayPicker: some View {
        Picker(selection: $dayOfMonth) {
            ForEach(1...28, id: \.self) { d in
                Text("\(d) 日").tag(d)
            }
        } label: {
            Text("每月几号扣款")
        }
    }

    /// 用户改频率/日期组件时,如果他没有手动碰过 DatePicker,则联动更新下次日期。
    /// 如果他已经手动调过 DatePicker,尊重他的选择。
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
