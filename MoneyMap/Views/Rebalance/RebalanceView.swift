import SwiftUI
import SwiftData

struct RebalanceView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var positions: [Position]
    @Query(filter: #Predicate<TransactionRecord> { $0.statusRaw == "PENDING" })
    private var pendingTxs: [TransactionRecord]
    @Query private var rates: [ExchangeRate]
    @Query(sort: \TargetAllocation.assetClassRaw) private var targets: [TargetAllocation]

    @AppStorage("rebalanceModelRaw") private var modelRaw: String = RebalanceModel.balanced.rawValue

    @State private var showEditSheet = false
    @State private var prefill: RebalancePrefill?

    private var currentModel: RebalanceModel {
        RebalanceModel(rawValue: modelRaw) ?? .balanced
    }

    private var rateMap: [String: Double] {
        var m: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { m[r.fromCurrency] = r.rate }
        return m
    }

    private var breakdown: AssetBreakdown {
        ValuationService.currentBreakdown(
            accounts: accounts,
            positions: positions,
            pendingTransactions: pendingTxs,
            rates: rateMap
        )
    }

    private var items: [RebalanceItem] {
        RebalanceService.compute(breakdown: breakdown, targets: targets)
    }

    private var overallDeviation: Double {
        RebalanceService.overallDeviation(items: items)
    }

    private var statusText: String {
        let d = overallDeviation
        if d < 2 { return "组合整体匹配目标,无需调整" }
        if d < 5 { return "轻微偏离,可暂不调整" }
        if d < 10 { return "建议适度调整" }
        return "偏离较大,建议尽快再平衡"
    }

    private var statusColor: Color {
        let d = overallDeviation
        if d < 2 { return .pnlNegative }
        if d < 5 { return .secondary }
        if d < 10 { return .orange }
        return .pnlPositive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if targets.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    comparisonCard
                    suggestionsCard
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("再平衡")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !targets.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TargetAllocationSheet()
        }
        .sheet(item: $prefill) { p in
            AddTransactionSheet(prefill: p)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "scalemass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("还没设置目标配置")
                .font(.headline)
            Text("设置每类资产的目标比例,系统会告诉你需要买入或卖出多少来匹配你的目标")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                showEditSheet = true
            } label: {
                Text("现在设置")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("整体偏离度")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption2)
                    Text(currentModel.displayName + "型")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", overallDeviation))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(statusText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardStyle()
    }

    private var comparisonCard: some View {
        Card(title: "当前 vs 目标") {
            VStack(spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: item.assetClass.hexColor))
                                    .frame(width: 8, height: 8)
                                Text(item.assetClass.displayName)
                                    .font(.subheadline.weight(.medium))
                            }
                            Spacer()
                            Text(String(format: "目标 %.0f%% · 当前 %.1f%%",
                                        item.targetPercent, item.currentPercent))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: item.assetClass.hexColor).opacity(0.15))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(Color(hex: item.assetClass.hexColor))
                                    .frame(width: max(2, geo.size.width * (item.currentPercent / 100)),
                                           height: 8)
                                // target marker
                                Rectangle()
                                    .fill(Color.primary.opacity(0.6))
                                    .frame(width: 2, height: 14)
                                    .offset(x: max(0, geo.size.width * (item.targetPercent / 100) - 1),
                                            y: -3)
                            }
                        }
                        .frame(height: 14)
                    }
                }

                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Capsule()
                            .fill(Theme.Palette.accent)
                            .frame(width: 12, height: 6)
                        Text("当前")
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.6))
                            .frame(width: 2, height: 10)
                        Text("目标")
                    }
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var suggestionsCard: some View {
        Card(title: "调整建议") {
            VStack(spacing: 0) {
                let actionable = items.filter { $0.action != .hold }
                if actionable.isEmpty {
                    Text("无需调整 ·  现在的组合就在目标范围内 👍")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                } else {
                    ForEach(actionable.sorted { abs($0.actionAmount) > abs($1.actionAmount) }) { item in
                        suggestionRow(item)
                        if item.id != actionable.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private func suggestionRow(_ item: RebalanceItem) -> some View {
        Button {
            prefill = RebalancePrefill(
                action: item.action == .buy ? .buy : .sell,
                assetClass: item.assetClass,
                amount: abs(item.actionAmount)
            )
        } label: {
            suggestionRowContent(item)
        }
        .buttonStyle(.plain)
    }

    private func suggestionRowContent(_ item: RebalanceItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(actionColor(item).opacity(0.15))
                Image(systemName: actionIcon(item))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(actionColor(item))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(actionLabel(item) + " " + item.assetClass.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: "%+.1f%%", item.deviationPercent))
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "当前 %.1f%% → 目标 %.0f%%",
                            item.currentPercent, item.targetPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.cnyTile(abs(item.actionAmount), signed: false))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(actionColor(item))
                HStack(spacing: 3) {
                    Text("去交易")
                        .font(.caption2)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionLabel(_ item: RebalanceItem) -> String {
        item.action == .buy ? "买入" : "卖出"
    }

    private func actionIcon(_ item: RebalanceItem) -> String {
        item.action == .buy ? "arrow.down.left" : "arrow.up.right"
    }

    private func actionColor(_ item: RebalanceItem) -> Color {
        item.action == .buy ? .pnlPositive : .pnlNegative
    }
}
