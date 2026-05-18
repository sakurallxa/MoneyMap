import SwiftUI
import SwiftData

struct EditPositionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let position: Position

    @State private var assetName: String
    @State private var sharesText: String
    @State private var avgCostText: String
    @State private var lastPriceText: String
    @FocusState private var focusedField: Field?

    enum Field { case lastPrice, shares, avgCost, name }

    init(position: Position) {
        self.position = position
        _assetName = State(initialValue: position.assetName)
        _sharesText = State(initialValue: String(format: "%.4f", position.shares))
        _avgCostText = State(initialValue: String(format: "%.4f", position.avgCost))
        _lastPriceText = State(initialValue: String(format: "%.4f", position.lastPrice))
    }

    private var canSave: Bool {
        !assetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(sharesText) ?? 0 > 0
    }

    /// 上次更新距今天数;用于在标题下方提示数据是否陈旧。
    private var daysSinceUpdate: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: position.updatedAt), to: cal.startOfDay(for: Date())).day ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if daysSinceUpdate >= 7 {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            Text("上次更新 \(daysSinceUpdate) 天前 · 建议核对最新价")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("最新价")
                        Spacer()
                        TextField("0.0000", text: $lastPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .lastPrice)
                    }
                } header: {
                    Text("当前价格")
                } footer: {
                    Text("自动行情拉取失败时,在这里手动维护最新价格。保存后总资产 / 累计盈亏会立即按新价重算。")
                }

                Section {
                    HStack {
                        Text("资产代码")
                        Spacer()
                        Text(position.assetCode)
                            .foregroundStyle(.secondary)
                    }
                    TextField("资产名称", text: $assetName)
                        .focused($focusedField, equals: .name)
                }

                Section("持仓") {
                    HStack {
                        Text("持有份额/股数")
                        Spacer()
                        TextField("0.00", text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .shares)
                    }
                    HStack {
                        Text("平均持仓成本")
                        Spacer()
                        TextField("0.0000", text: $avgCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .avgCost)
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
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
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
            }
            .onAppear {
                // 自动 focus 最新价字段 — 90% 的编辑诉求是来更新价格
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .lastPrice
                }
            }
        }
    }

    private func save() {
        position.assetName = assetName.trimmingCharacters(in: .whitespaces)
        position.shares = Double(sharesText) ?? 0
        position.avgCost = Double(avgCostText) ?? 0
        if let newPrice = Double(lastPriceText), newPrice > 0 {
            position.lastPrice = newPrice
        }
        position.updatedAt = Date()
        do {
            try context.save()
            ToastManager.shared.success("已保存持仓")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
