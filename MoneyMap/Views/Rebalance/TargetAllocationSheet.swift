import SwiftUI
import SwiftData

struct TargetAllocationSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [TargetAllocation]
    @AppStorage("rebalanceModelRaw") private var modelRaw: String = RebalanceModel.balanced.rawValue

    @State private var percents: [AssetClass: Double] = [:]
    @State private var selectedModel: RebalanceModel = .balanced
    @State private var didInit = false

    private var total: Double {
        AssetClass.allCases.reduce(0.0) { $0 + (percents[$1] ?? 0) }
    }

    private var isValid: Bool {
        if selectedModel != .custom { return true }
        return abs(total - 100) < 0.01
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("模式", selection: $selectedModel) {
                        ForEach(RebalanceModel.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(selectedModel.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("选择模式")
                }

                Section {
                    ForEach(AssetClass.allCases, id: \.self) { cls in
                        allocationRow(for: cls)
                    }
                } header: {
                    Text(selectedModel == .custom ? "拖动滑块设置目标比例" : "预设比例(锁定)")
                } footer: {
                    HStack {
                        Text("总计")
                        Spacer()
                        Text(String(format: "%.0f%%", total))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isValid ? .green : .red)
                    }
                }

                if selectedModel == .custom && !isValid {
                    Section {
                        Text(total > 100 ? "总和超出 100%,请减少某项" : "总和不足 100%,请补齐")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("调整目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                guard !didInit else { return }
                didInit = true
                loadFromStore()
            }
            .onChange(of: selectedModel) { _, newModel in
                applyModel(newModel)
            }
        }
    }

    private func allocationRow(for cls: AssetClass) -> some View {
        let editable = selectedModel == .custom
        return HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: cls.hexColor))
                .frame(width: 10, height: 10)
            Text(cls.displayName)
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(editable ? .primary : .secondary)
            Slider(
                value: Binding(
                    get: { percents[cls] ?? 0 },
                    set: { percents[cls] = $0.rounded() }
                ),
                in: 0...100,
                step: 1
            )
            .disabled(!editable)
            Text(String(format: "%.0f%%", percents[cls] ?? 0))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(editable ? .primary : .secondary)
        }
    }

    private func loadFromStore() {
        let storedModel = RebalanceModel(rawValue: modelRaw) ?? .balanced
        selectedModel = storedModel

        if existing.isEmpty {
            applyModel(storedModel == .custom ? .balanced : storedModel)
        } else {
            for t in existing {
                percents[t.assetClass] = t.targetPercent
            }
            for cls in AssetClass.allCases where percents[cls] == nil {
                percents[cls] = 0
            }
        }
    }

    private func applyModel(_ model: RebalanceModel) {
        guard model != .custom else { return }
        for cls in AssetClass.allCases {
            percents[cls] = model.presetTargets[cls] ?? 0
        }
    }

    private func save() {
        for t in existing {
            context.delete(t)
        }
        for cls in AssetClass.allCases {
            let p = percents[cls] ?? 0
            guard p > 0 else { continue }
            context.insert(TargetAllocation(assetClass: cls, percent: p))
        }
        modelRaw = selectedModel.rawValue
        try? context.save()
        dismiss()
    }
}
