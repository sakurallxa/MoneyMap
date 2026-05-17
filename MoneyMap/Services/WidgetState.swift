import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftData

/// 主 App 与 Widget Extension 共享的快照状态。
/// 通过 App Group UserDefaults 跨进程传值。
enum WidgetState {
    /// ⚠️ 必须和你在 Xcode 里给主 App + Widget Target 配置的 App Group ID 完全一致。
    static let appGroupID = "group.com.lusansui.MoneyMap"

    static let keyTotal = "widgetTotalCNY"
    static let keyDailyChange = "widgetDailyChange"
    static let keyDailyPct = "widgetDailyPct"
    static let keyUpdatedAt = "widgetUpdatedAt"

    @MainActor
    static func push(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let rates = (try? context.fetch(FetchDescriptor<ExchangeRate>())) ?? []
        var rateMap: [String: Double] = ["CNY": 1.0, "HKD": 0.92, "USD": 7.18]
        for r in rates { rateMap[r.fromCurrency] = r.rate }

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        let pending = (try? context.fetch(FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.statusRaw == "PENDING" }
        ))) ?? []

        let breakdown = ValuationService.currentBreakdown(
            accounts: accounts, positions: positions,
            pendingTransactions: pending, rates: rateMap
        )

        var current = 0.0
        var prev = 0.0
        for p in positions {
            let fx = rateMap[p.effectiveCurrency.rawValue] ?? 1.0
            current += p.shares * p.lastPrice * fx
            prev += p.shares * p.prevClosePrice * fx
        }
        let delta = current - prev
        let cashCNY = accounts.reduce(0.0) { sum, a in
            sum + a.cashBalance * (rateMap[a.currency.rawValue] ?? 1.0)
        }
        let baseTotal = prev + cashCNY
        let pct = baseTotal > 0 ? delta / baseTotal * 100 : 0

        defaults.set(breakdown.total, forKey: keyTotal)
        defaults.set(delta, forKey: keyDailyChange)
        defaults.set(pct, forKey: keyDailyPct)
        defaults.set(Date(), forKey: keyUpdatedAt)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
