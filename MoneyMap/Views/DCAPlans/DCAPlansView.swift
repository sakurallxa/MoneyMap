import SwiftUI
import SwiftData

struct DCAPlansView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DCAPlan.nextRunDate) private var plans: [DCAPlan]
    @State private var showAddSheet = false
    @State private var editingPlan: DCAPlan?

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(plans) { plan in
                            DCAPlanRow(plan: plan)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingPlan = plan
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        context.delete(plan)
                                        try? context.save()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }

                                    Button {
                                        plan.isActive.toggle()
                                        try? context.save()
                                    } label: {
                                        Label(plan.isActive ? "暂停" : "启用",
                                              systemImage: plan.isActive ? "pause.fill" : "play.fill")
                                    }
                                    .tint(plan.isActive ? .orange : .green)

                                    Button {
                                        editingPlan = plan
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .listRowSpacing(12)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("定投计划")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDCAPlanSheet()
            }
            .sheet(item: $editingPlan) { plan in
                EditDCAPlanSheet(plan: plan)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("还没有定投计划")
                .font(.headline)
            Text("点击右上角 + 创建,系统会自动扣款并 T+1 确认份额")
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
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    @State private var showAddSheetForEmpty = false
}

struct DCAPlanRow: View {
    let plan: DCAPlan

    private var daysUntilNext: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let next = cal.startOfDay(for: plan.nextRunDate)
        return cal.dateComponents([.day], from: today, to: next).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(plan.targetAssetName) · \(plan.targetAssetCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PillTag(
                    text: plan.isActive ? "进行中" : "已暂停",
                    color: plan.isActive ? .green : .gray
                )
            }

            HStack(spacing: 10) {
                metricColumn("每次", CurrencyFormatter.cnyString(plan.amount))
                metricColumn("频率", plan.frequency.displayName)
                metricColumn(daysUntilNext >= 0 ? "距下次" : "已逾期", daysLabel)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text("\(plan.sourceAccountName) → \(plan.targetAccountName)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("下次扣款 \(DateUtil.dateOnly.string(from: plan.nextRunDate))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var daysLabel: String {
        if daysUntilNext == 0 { return "今天" }
        if daysUntilNext > 0 { return "\(daysUntilNext) 天" }
        return "\(-daysUntilNext) 天前"
    }

    private func metricColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    DCAPlansView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self], inMemory: true)
}
