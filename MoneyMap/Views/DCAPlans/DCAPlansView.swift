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
            Group {
                if plans.isEmpty {
                    VStack(spacing: 0) {
                        headerRow
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                        emptyView
                    }
                } else {
                    listView
                }
            }
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

    /// 顶部:定投标题 + 月度小字 + 右侧「+」按钮(与 Dashboard/账户/交易 一致)
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("定投")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            Text(navSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.accent)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.Palette.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 6 }
        }
        .padding(.horizontal, 4)
    }

    private var listView: some View {
        List {
            Section {
                headerRow
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 4, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                amberBanner
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
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
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
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
        .listRowSpacing(8)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 14, for: .scrollContent)
    }

    // 顶部琥珀色 banner
    private var amberBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text("到期当日自动生成定投记录,T+N 确认份额,更新总资产和收益数据")
                .font(.system(size: 12))
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

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("还没有定投计划")
                .font(.headline)
            Text("点击右上角 + 创建,到期当日会自动生成定投记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showAddSheet = true
            } label: {
                Text("立即创建")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.Palette.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 0) {
                        Text(plan.targetAssetName)
                        Text(" · ")
                            .foregroundStyle(.tertiary)
                        Text(plan.targetAssetCode)
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
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
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                Text(plan.targetAccountName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(dimmed ? 0.6 : 1.0)
    }

    /// 状态胶囊 — 浅色底 + 深色文字,克制不抢眼。
    private var statusPill: some View {
        let isActive = plan.isActive
        let bg: Color = isActive ? Color.pnlNegative.opacity(0.14) : Color.black.opacity(0.06)
        let fg: Color = isActive ? Color.pnlNegative : .secondary
        return Text(isActive ? "进行中" : "已暂停")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(danger ? Color.pnlNegative : .secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
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
