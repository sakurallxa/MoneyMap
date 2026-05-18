import SwiftUI
import SwiftData

enum TxFilterType: String, CaseIterable {
    case all, pending, completed
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .pending: return "在途"
        case .completed: return "已完成"
        }
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.tradeDate, order: .reverse) private var transactions: [TransactionRecord]
    @AppStorage("hideBalance") private var hideBalance = false

    @State private var filter: TxFilterType = .all
    @State private var selectedYear: Int? = nil
    @State private var searchText: String = ""
    @State private var showPicker = false
    @State private var deleteCandidate: TransactionRecord? = nil

    private var availableYears: [Int] {
        let cal = Calendar.current
        let years = Set(transactions.map { cal.component(.year, from: $0.tradeDate) })
        return years.sorted(by: >)
    }

    private var filteredTxs: [TransactionRecord] {
        var list = transactions

        // Status filter
        switch filter {
        case .all: break
        case .pending: list = list.filter { $0.status == .pending }
        case .completed: list = list.filter { $0.status == .completed || $0.status == .confirmed }
        }

        // Year filter
        if let year = selectedYear {
            let cal = Calendar.current
            list = list.filter { cal.component(.year, from: $0.tradeDate) == year }
        }

        // Search
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.assetName.lowercased().contains(q) ||
                $0.assetCode.lowercased().contains(q) ||
                $0.note.lowercased().contains(q) ||
                $0.fromAccountName.lowercased().contains(q) ||
                $0.toAccountName.lowercased().contains(q)
            }
        }

        return list
    }

    private var pendingTxs: [TransactionRecord] {
        transactions.filter { $0.status == .pending }
    }

    /// 本月统计
    private var monthlyStats: (count: Int, netFlow: Double) {
        let cal = Calendar.current
        let now = Date()
        let thisMonth = transactions.filter {
            cal.component(.year, from: $0.tradeDate) == cal.component(.year, from: now) &&
            cal.component(.month, from: $0.tradeDate) == cal.component(.month, from: now)
        }
        let netFlow = thisMonth.reduce(0.0) { $0 + $1.signedAmount }
        return (thisMonth.count, netFlow)
    }

    /// 按日分组
    private var groupedByDate: [(date: Date, items: [TransactionRecord])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredTxs) {
            cal.startOfDay(for: $0.tradeDate)
        }
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    private var allCount: Int { transactions.count }
    private var pendingCount: Int { pendingTxs.count }
    private var completedCount: Int { transactions.filter { $0.status == .completed || $0.status == .confirmed }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerRow
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 10, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    searchBar
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    filterStrip
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if !pendingTxs.isEmpty && filter != .completed {
                        pendingBanner
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                if groupedByDate.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(groupedByDate, id: \.date) { group in
                        Section {
                            ForEach(group.items) { tx in
                                TransactionRow(tx: tx, hideAmount: hideBalance)
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                    .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteCandidate = tx
                                        } label: {
                                            Label(tx.status == .pending ? "取消" : "删除", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text(formatGroupDate(group.date))
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(.tertiary)
                                .textCase(nil)
                                .padding(.leading, 2)
                                .padding(.bottom, 2)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(12)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 14, for: .scrollContent)
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showPicker) {
                TransactionTypePickerView()
            }
            .alert("删除这笔交易?",
                   isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } })
            ) {
                Button("取消", role: .cancel) { deleteCandidate = nil }
                Button("删除", role: .destructive) {
                    if let tx = deleteCandidate { performDelete(tx) }
                    deleteCandidate = nil
                }
            } message: {
                Text(deleteAlertMessage)
            }
        }
    }

    private var deleteAlertMessage: String {
        guard let tx = deleteCandidate else { return "" }
        if tx.status == .pending {
            return "撤销该在途交易,扣款会回退到现金账户。"
        }
        return "持仓 / 账户余额会自动按这笔交易反向回退,保持数据一致。"
    }

    private func performDelete(_ tx: TransactionRecord) {
        do {
            try TransactionReversalService.deleteWithReversal(tx, context: context)
            ToastManager.shared.success("已删除并回退资产")
        } catch {
            ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
        }
    }

    /// 顶部:交易标题 + 月度小字 + 右侧「+」按钮(与标题同基线)
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("交易")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            Text(navSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            Button {
                showPicker = true
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
    }

    private var navSubtitle: String {
        let netFlowText = monthlyStats.netFlow >= 0
            ? "净流入 ¥\(formatNumber(abs(monthlyStats.netFlow)))"
            : "净流出 ¥\(formatNumber(abs(monthlyStats.netFlow)))"
        return "本月 \(monthlyStats.count) 笔 · \(netFlowText)"
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            TextField("搜索资产、备注、账户...", text: $searchText)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 6)
    }

    private var filterStrip: some View {
        HStack(spacing: 8) {
            chipButton(.all, count: allCount)
            chipButton(.pending, count: pendingCount)
            chipButton(.completed, count: completedCount)
            Spacer()
            if !availableYears.isEmpty {
                Menu {
                    Button("全部年份") { selectedYear = nil }
                    Divider()
                    ForEach(availableYears, id: \.self) { y in
                        Button("\(y) 年") { selectedYear = y }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(selectedYear.map { "\($0) 年" } ?? "全部年份")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.045))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func chipButton(_ f: TxFilterType, count: Int) -> some View {
        let selected = filter == f
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { filter = f }
        } label: {
            HStack(spacing: 4) {
                Text(f.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 11))
                    .opacity(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.primary : Color.black.opacity(0.045))
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var pendingBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#E89B2A"))
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(pendingTxs.count) 笔在途 · T+1/T+2 自动确认")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8A5A0F"))
                Text("无需操作 · 确认后自动入仓并提醒你")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#A57628"))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color(hex: "#FFF4DE"), Color(hex: "#FFEAD0")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "暂无符合条件的交易" : "没找到匹配的交易")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("点右上 + 记一笔新交易")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func formatGroupDate(_ d: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            f.dateFormat = "M月d日"
        } else {
            f.dateFormat = "yyyy年M月d日"
        }
        return f.string(from: d)
    }

    private func formatNumber(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Account.self, Position.self, TransactionRecord.self, DailySnapshot.self, DCAPlan.self, Asset.self, PriceQuote.self, ExchangeRate.self, TargetAllocation.self], inMemory: true)
}
