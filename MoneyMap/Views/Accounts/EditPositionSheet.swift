import SwiftUI
import SwiftData

struct EditPositionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let position: Position

    @State private var assetName: String
    @State private var sharesText: String
    @State private var avgCostText: String

    init(position: Position) {
        self.position = position
        _assetName = State(initialValue: position.assetName)
        _sharesText = State(initialValue: String(format: "%.4f", position.shares))
        _avgCostText = State(initialValue: String(format: "%.4f", position.avgCost))
    }

    private var canSave: Bool {
        !assetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(sharesText) ?? 0 > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("资产代码")
                        Spacer()
                        Text(position.assetCode)
                            .foregroundStyle(.secondary)
                    }
                    TextField("资产名称", text: $assetName)
                }

                Section("持仓") {
                    HStack {
                        Text("持有份额/股数")
                        Spacer()
                        TextField("0.00", text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("平均持仓成本")
                        Spacer()
                        TextField("0.0000", text: $avgCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("编辑持仓")
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
        position.assetName = assetName.trimmingCharacters(in: .whitespaces)
        position.shares = Double(sharesText) ?? 0
        position.avgCost = Double(avgCostText) ?? 0
        position.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}
