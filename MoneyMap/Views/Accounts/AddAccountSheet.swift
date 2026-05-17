import SwiftUI
import SwiftData

struct AddAccountSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var currency: CurrencyCode = .cny
    @State private var cashBalanceText = ""
    @State private var note = ""

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("账户名称（如:招行储蓄卡）", text: $name)
                    Picker("账户类型", selection: $type) {
                        ForEach(AccountType.userSelectable, id: \.self) { t in
                            Label(t.displayName, systemImage: t.iconName).tag(t)
                        }
                    }
                    Picker("币种", selection: $currency) {
                        ForEach(CurrencyCode.allCases, id: \.self) { c in
                            Text("\(c.rawValue) \(c.symbol)").tag(c)
                        }
                    }
                }

                Section("初始余额") {
                    TextField("0.00", text: $cashBalanceText)
                        .keyboardType(.decimalPad)
                }

                Section("备注（可选）") {
                    TextField("用途说明", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("添加账户")
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
        }
    }

    private func save() {
        let balance = Double(cashBalanceText) ?? 0
        let acc = Account(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            currency: currency,
            cashBalance: balance,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        context.insert(acc)
        try? context.save()
        dismiss()
    }
}
