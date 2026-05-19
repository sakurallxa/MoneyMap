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
        case .completed: list = list.filter { $0.status.isSettled }
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
        // 月度净流入用净现金流(含手续费),与列表 row 展示一致
        let netFlow = thisMonth.reduce(0.0) { $0 + $1.netSignedCashAmount }
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
    private var completedCount: Int { transactions.filter { $0.status.isSettled }.count }

    var body: some View {
        NavigationStack {
            if transactions.isEmpty {
                transactionsEmptyContainer
            } else {
                listContent
            }
        }
    }

    private var transactionsEmptyContainer: some View {
        TransactionsEmptyV2(
            monthCountText: navSubtitle,
            addAction: { showPicker = true }
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showPicker) {
            TransactionTypePickerView()
        }
    }

    @ViewBuilder
    private var listContent: some View {
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if groupedByDate.isEmpty {
                Section {
                    noMatchEmptyState
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
                                .font(Theme.serif(11, weight: .bold))
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
            SnapshotService.recordToday(context: context)
            ToastManager.shared.success("已删除并回退资产")
        } catch {
            ToastManager.shared.error("删除失败", subtitle: error.localizedDescription)
        }
    }

    /// 顶部:交易标题 + 月度小字 + 右侧「眼睛 + 」按钮(P0-005, P0-006)
    private var headerRow: some View {
        PageHeader(title: "交易", subtitle: navSubtitle) {
            HStack(spacing: 6) {
                HideBalanceToggle()
                BronzeAddButton { showPicker = true }
            }
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
                .font(Theme.serif(14))
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
                            .font(Theme.serif(13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.045))
                    .clipShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .tint(.primary)
            }
        }
        .padding(.horizontal, 6)
    }

    /// P1-016:统一走 SegmentedChip
    @ViewBuilder
    private func chipButton(_ f: TxFilterType, count: Int) -> some View {
        SegmentedChip(title: f.displayName, count: count, selected: filter == f) {
            withAnimation(.easeInOut(duration: 0.15)) { filter = f }
        }
    }

    /// 已有交易但当前过滤命中 0
    private var noMatchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.EmptyV2.text3)
                .padding(.bottom, 2)
            Text(searchText.isEmpty ? "没有符合条件的交易" : "没找到匹配的交易")
                .font(Theme.serif(15, weight: .semibold))
                .foregroundStyle(Theme.EmptyV2.text1)
            Text("换个状态、年份或搜索词试试")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.EmptyV2.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
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
