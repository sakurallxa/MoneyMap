import Foundation
import SwiftData

/// 每日资产总值快照写入服务。
///
/// 任何会改变"总资产"的路径都应该在事后调一次 `recordToday(context:)`:
///   - PriceRefreshService.refreshAll 结束后
///   - TransactionFormView.save 保存交易后
///   - TransactionReversalService.deleteWithReversal 删除后
///   - DataImportService 导入后
///   - AddAccountSheet / EditAccountSheet 保存后
///   - AddPositionSheet / EditPositionSheet 保存后
///   - DCAService.confirmRipePending 自动确认后
///
/// 没有这个服务的话,Dashboard 趋势图永远显示"数据不足"。
enum SnapshotService {

    /// 计算当前总资产并写入今天的 DailySnapshot,然后同步推送 Widget。
    /// 当天已有快照 → 更新 totalValueCNY 等字段;没有 → 插入新快照。
    /// 失败静默(不抛错给业务调用方),只 debug log。
    /// **P2.1**:末尾自动调 WidgetState.push,确保 Widget 始终与 App 内数据一致。
    @MainActor
    static func recordToday(context: ModelContext) {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        let pending = (try? context.fetch(
            FetchDescriptor<TransactionRecord>(
                predicate: #Predicate { $0.statusRaw == "PENDING" }
            )
        )) ?? []
        let rates = (try? context.fetch(FetchDescriptor<ExchangeRate>())) ?? []
        var rateMap: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { rateMap[r.fromCurrency] = r.rate }

        let breakdown = ValuationService.currentBreakdown(
            accounts: accounts,
            positions: positions,
            pendingTransactions: pending,
            rates: rateMap
        )

        let today = Calendar.current.startOfDay(for: Date())
        let existingDescriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date == today }
        )
        let existing = (try? context.fetch(existingDescriptor))?.first

        // 计算今日相对昨日变动(用于 dailyChange / dailyChangePct)
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayDescriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date < today && $0.date >= yesterdayStart }
        )
        let yesterdayValue = (try? context.fetch(yesterdayDescriptor))?.first?.totalValueCNY ?? 0
        let dailyChange = yesterdayValue > 0 ? breakdown.total - yesterdayValue : 0
        let dailyChangePct = yesterdayValue > 0 ? dailyChange / yesterdayValue * 100 : 0

        if let existing {
            existing.totalValueCNY = breakdown.total
            existing.cashValue = breakdown.cash
            existing.moneyFundValue = breakdown.moneyFund
            existing.fundValue = breakdown.fund
            existing.stockAValue = breakdown.stockA
            existing.stockHKValue = breakdown.stockHK
            existing.stockUSValue = breakdown.stockUS
            existing.pendingValue = breakdown.pending
            existing.dailyChange = dailyChange
            existing.dailyChangePct = dailyChangePct
        } else {
            let snap = DailySnapshot(
                date: today,
                totalValueCNY: breakdown.total,
                cashValue: breakdown.cash,
                moneyFundValue: breakdown.moneyFund,
                fundValue: breakdown.fund,
                stockAValue: breakdown.stockA,
                stockHKValue: breakdown.stockHK,
                stockUSValue: breakdown.stockUS,
                pendingValue: breakdown.pending,
                dailyChange: dailyChange,
                dailyChangePct: dailyChangePct
            )
            context.insert(snap)
        }
        try? context.save()
        // P2.1:写完 snapshot 自动推送 Widget — 把"写快照"和"推 widget"绑定,
        // 避免业务调用方漏掉其中一步导致 Widget 与 App 数据脱节。
        WidgetState.push(context: context)
    }
}
