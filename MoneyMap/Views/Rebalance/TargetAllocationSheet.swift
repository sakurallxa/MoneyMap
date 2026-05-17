import SwiftUI
import SwiftData

struct TargetAllocationSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [TargetAllocation]
    @AppStorage("rebalanceModelRaw") private var modelRaw: String = RebalanceModel.balanced.rawValue
    @AppStorage("lastRebalanceDate") private var lastRebalanceTimestamp: Double = 0

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
            ScrollView {
                VStack(spacing: 16) {
                    modeCardsScroll
                    livePreviewCard
                    sliderListCard
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                stickyCTA
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("目标配置")
                            .font(.system(size: 15, weight: .semibold))
                        Text("每类资产的目标占比")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
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

    // MARK: - 模式卡横滑

    private var modeCardsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RebalanceModel.allCases, id: \.self) { m in
                    modeCard(m)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func modeCard(_ m: RebalanceModel) -> some View {
        let selected = selectedModel == m
        return Button {
            selectedModel = m
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // mini donut
                if m == .custom {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accentDark)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Circle())
                } else {
                    DonutChart(
                        segments: m.presetTargets.map { kv in
                            DonutChart.DonutSegment(
                                id: kv.key.rawValue,
                                value: kv.value,
                                color: Color(hex: kv.key.hexColor)
                            )
                        },
                        thickness: 9,
                        gapDegrees: 1
                    )
                    .frame(width: 48, height: 48)
                }

                Text(m.displayName + "型")
                    .font(.system(size: 14, weight: .bold))
                Text(m.tagline)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if selected {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, Theme.Palette.accent)
                    }
                }
            }
            .padding(12)
            .frame(width: 136, height: 156, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.Palette.accent.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.Palette.accent : Color.clear, lineWidth: 2)
            )
            .shadow(color: selected ? Theme.Palette.accent.opacity(0.22) : .black.opacity(0.04), radius: selected ? 14 : 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 实时预览

    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedModel.displayName + "型 · 预览")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                validityBadge
            }
            Text(selectedModel.tagline)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // stacked bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(AssetClass.allCases, id: \.self) { cls in
                        let pct = (percents[cls] ?? 0) / 100
                        if pct > 0 {
                            Color(hex: cls.hexColor)
                                .frame(width: max(1, geo.size.width * pct - 1))
                        }
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // 7 类色点图例
            HStack(spacing: 12) {
                ForEach(AssetClass.allCases.prefix(4), id: \.self) { cls in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: cls.hexColor))
                            .frame(width: 6, height: 6)
                        Text("\(cls.displayName) \(Int(percents[cls] ?? 0))%")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
            HStack(spacing: 12) {
                ForEach(Array(AssetClass.allCases.dropFirst(4)), id: \.self) { cls in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: cls.hexColor))
                            .frame(width: 6, height: 6)
                        Text("\(cls.displayName) \(Int(percents[cls] ?? 0))%")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                }
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

    private var validityBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isValid ? "总和 100%" : String(format: "当前 %.0f%%", total))
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isValid ? Color.pnlNegative : Color.orange)
        .clipShape(Capsule())
    }

    // MARK: - 类别滑块列表

    private var sliderListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(AssetClass.allCases.enumerated()), id: \.element) { idx, cls in
                sliderRow(cls)
                if idx < AssetClass.allCases.count - 1 {
                    Divider().opacity(0.4).padding(.leading, 18)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func sliderRow(_ cls: AssetClass) -> some View {
        let editable = selectedModel == .custom
        return HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: cls.hexColor))
                .frame(width: 10, height: 10)
            Text(cls.displayName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(editable ? .primary : .secondary)
            Slider(
                value: Binding(
                    get: { percents[cls] ?? 0 },
                    set: { percents[cls] = $0.rounded() }
                ),
                in: 0...50,
                step: 1
            )
            .tint(Color(hex: cls.hexColor))
            .disabled(!editable)
            Text(String(format: "%.0f%%", percents[cls] ?? 0))
                .font(.system(size: 15, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(editable ? .primary : .secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sticky CTA

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.Palette.pageBgWarm.opacity(0), Theme.Palette.pageBgWarm],
                           startPoint: .top, endPoint: .bottom)
            .frame(height: 16)

            Button {
                save()
            } label: {
                Text(ctaText)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isValid ? Theme.Palette.accent : Theme.Palette.accent.opacity(0.45))
                    )
                    .shadow(color: Theme.Palette.accent.opacity(isValid ? 0.34 : 0), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .background(Theme.Palette.pageBgWarm)
        }
    }

    private var ctaText: String {
        if isValid {
            return "保存 · \(selectedModel.displayName)型"
        }
        return String(format: "总和需要 = 100% (当前 %.0f%%)", total)
    }

    // MARK: - load / apply / save

    private func loadFromStore() {
        let storedModel = RebalanceModel(rawValue: modelRaw) ?? .balanced
        selectedModel = storedModel
        if existing.isEmpty {
            applyModel(storedModel == .custom ? .balanced : storedModel)
        } else {
            for t in existing { percents[t.assetClass] = t.targetPercent }
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
        for t in existing { context.delete(t) }
        for cls in AssetClass.allCases {
            let p = percents[cls] ?? 0
            guard p > 0 else { continue }
            context.insert(TargetAllocation(assetClass: cls, percent: p))
        }
        modelRaw = selectedModel.rawValue
        lastRebalanceTimestamp = Date().timeIntervalSince1970
        do {
            try context.save()
            ToastManager.shared.success("已保存目标配置 · \(selectedModel.displayName)型")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
