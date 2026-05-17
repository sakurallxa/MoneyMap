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
                    TextField("如:每周一定投易方达蓝筹", text: $planName)
                }

                Section("扣款来源") {
                    if sourceAccounts.isEmpty {
                        Text("请先添加一个现金/货基类型的账户")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Picker("扣款账户", selection: $sourceAccountID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(sourceAccounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                    }
                }

                Section("买入目标") {
                    if targetAccounts.isEmpty {
                        Text("请先添加一个基金/证券类型的账户")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Picker("目标账户", selection: $targetAccountID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(targetAccounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                    }
                    TextField("资产代码(如 005827)", text: $assetCode)
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
                }

                Section {
                    Text("到了扣款日,系统会自动从来源账户扣款并生成「在途」交易;T+1 后自动按确认净值入仓。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建定投计划")
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
        try? context.save()
        dismiss()
    }
}
