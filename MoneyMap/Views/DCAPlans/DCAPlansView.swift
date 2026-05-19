import SwiftUI
import SwiftData

struct DCAPlansView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DCAPlan.nextRunDate) private var plans: [DCAPlan]
    @State private var showAddSheet = false
    @State private var editingPlan: DCAPlan?

    private var activePlans: [DCAPlan] { plans.filter { $0.isActive } }

    /// 每月预估扣款总额(每周/每两周按 4.33 / 2.17 折算,日按 30 折算)
    private var monthlyEstimate: Double {
        activePlans.reduce(0.0) { acc, p in
            switch p.frequency {
            case .daily:    return acc + p.amount * 30
            case .weekly:   return acc + p.amount * 4
            case .biweekly: return acc + p.amount * 2
            case .monthly:  return acc + p.amount
            }
        }
    }

    private var navSubtitle: String {
        if plans.isEmpty { return "尚未创建定投" }
        return "\(plans.count) 个计划 · 每月 \(CurrencyFormatter.cnyString(monthlyEstimate))"
    }

    var body: some View {
        NavigationStack {
            if plans.isEmpty {
                DCAEmptyV2(addAction: { showAddSheet = true })
                    .navigationBarHidden(true)
                    .sheet(isPresented: $showAddSheet) {
                        AddDCAPlanSheet()
                    }
            } else {
                listView
                    .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
                    .navigationBarHidden(true)
                    .sheet(isPresented: $showAddSheet) {
                        AddDCAPlanSheet()
                    }
                    .sheet(item: $editingPlan) { plan in
                        EditDCAPlanSheet(plan: plan)
                    }
            }
        }
    }

    /// 顶部:定投标题 + 副标 + 右侧「眼睛 + 」按钮(P0-005, P0-006)
    private var headerRow: some View {
        PageHeader(title: "定投", subtitle: navSubtitle) {
            HStack(spacing: 6) {
                HideBalanceToggle()
                BronzeAddButton { showAddSheet = true }
            }
        }
    }

    private var listView: some View {
        List {
            Section {
                headerRow
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                amberBanner
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(plans) { plan in
                    DCAPlanCard(plan: plan)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture { editingPlan = plan }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletePlan(plan)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                togglePause(plan)
                            } label: {
                                Label(plan.isActive ? "暂停" : "启用",
                                      systemImage: plan.isActive ? "pause.fill" : "play.fill")
                            }
                            .tint(.orange)
                            Button {
                                editingPlan = plan
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(12)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 14, for: .scrollContent)
    }

    // 顶部琥珀色 banner(P2-020:用空态的自绘 calendar icon 24px 取代 SF Symbol)
    private var amberBanner: some View {
        HStack(spacing: 10) {
            IconDCACal(size: 30)
            Text("到期当日自动生成定投记录,T+N 确认份额,更新总资产和收益数据")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.Palette.accentDark)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Palette.accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Palette.accent.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func togglePause(_ plan: DCAPlan) {
        plan.isActive.toggle()
        do {
            try context.save()
            ToastManager.shared.info(plan.isActive ? "已启用「\(plan.name)」" : "已暂停「\(plan.name)」")
        } catch {
            ToastManager.shared.error("操作失败", subtitle: error.localizedDescription)
        }
    }

    private func deletePlan(_ plan: DCAPlan) {
        let name = plan.name
        context.delete(plan)
        do {
            try context.save()
            ToastManager.shared.success("已删除「\(name)」")
        } catch {
            ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
        }
    }
}

// MARK: - Plan Card

struct DCAPlanCard: View {
    let plan: DCAPlan

    private var daysUntilNext: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let next = cal.startOfDay(for: plan.nextRunDate)
        return cal.dateComponents([.day], from: today, to: next).day ?? 0
    }

    private var overdue: Bool { plan.isActive && daysUntilNext < 0 }
    private var dimmed: Bool { !plan.isActive || overdue }

    private var nextLabel: String {
        if overdue { return "\(-daysUntilNext) 天前" }
        if daysUntilNext == 0 { return "今天" }
        if daysUntilNext == 1 { return "明天" }
        return DateUtil.dateOnly.string(from: plan.nextRunDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶行: 计划名 + 资产 · 代码 + 状态胶囊
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 0) {
                        Text(plan.targetAssetName)
                        Text(" · ")
                            .foregroundStyle(.tertiary)
                        Text(plan.targetAssetCode)
                            .monospacedDigit()
                    }
                    .font(Theme.serif(11))
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                statusPill
            }

            // 3 列 metric
            HStack(spacing: 8) {
                metricCell(label: "每次", value: CurrencyFormatter.cnyString(plan.amount), danger: false)
                metricCell(label: "频率", value: frequencyLabel, danger: false)
                metricCell(label: overdue ? "已逾期" : "下次", value: nextLabel, danger: overdue)
            }

            // 底行: 资金流向
            HStack(spacing: 8) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5B8FF9"))
                Text(plan.sourceAccountName)
                    .font(Theme.serif(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                Text(plan.targetAccountName)
                    .font(Theme.serif(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(dimmed ? 0.6 : 1.0)
    }

    /// 状态胶囊 — 浅色底 + 深色文字,克制不抢眼。
    /// P1-016 + P2-022:走统一 StatusPill 组件,active=铜色 / paused=灰
    private var statusPill: some View {
        StatusPill(
            text: plan.isActive ? "进行中" : "已暂停",
            tone: plan.isActive ? .active : .paused
        )
    }

    private var frequencyLabel: String {
        switch plan.frequency {
        case .daily:    return "每天"
        case .weekly:   return "周" + WeekdayPicker.labels[max(0, min(6, plan.dayOfWeek - 1))]
        case .biweekly: return "双周" + WeekdayPicker.labels[max(0, min(6, plan.dayOfWeek - 1))]
        case .monthly:  return "每月 \(plan.dayOfMonth) 日"
        }
    }

    private func metricCell(label: String, value: String, danger: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.serif(10, weight: .semibold))
                .foregroundStyle(danger ? Color.pnlNegative : .secondary)
            Text(value)
                .font(Theme.serif(13, weight: .bold))
                .foregroundStyle(danger ? Color.pnlNegative : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(danger ? Color.pnlNegative.opacity(0.08) : Color.black.opacity(0.04))
        )
    }
}

#Preview {
    DCAPlansView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
