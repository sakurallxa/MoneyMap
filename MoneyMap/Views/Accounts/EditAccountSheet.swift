import SwiftUI
import SwiftData

struct EditAccountSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account

    @State private var name: String
    @State private var type: AccountType
    @State private var currency: CurrencyCode
    @State private var cashBalanceText: String
    @State private var note: String

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _type = State(initialValue: account.type)
        _currency = State(initialValue: account.currency)
        _cashBalanceText = State(initialValue: String(format: "%.2f", account.cashBalance))
        _note = State(initialValue: account.note)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("账户名称", text: $name)
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

                Section {
                    TextField("0.00", text: $cashBalanceText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("现金余额")
                } footer: {
                    Text("银行卡/活期/货基账户的当前余额。每周/每月对一下账,保持准确。")
                }

                Section("备注") {
                    TextField("用途说明", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("编辑账户")
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
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.typeRaw = type.rawValue
        account.currencyRaw = currency.rawValue
        account.cashBalance = Double(cashBalanceText) ?? 0
        account.note = note.trimmingCharacters(in: .whitespaces)
        account.updatedAt = Date()
        do {
            try context.save()
            ToastManager.shared.success("已保存账户")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
