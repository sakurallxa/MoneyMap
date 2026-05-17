import Foundation
import SwiftData

enum DCAService {
    static func processAll(context: ModelContext, today: Date = Date()) {
        let plans = (try? context.fetch(FetchDescriptor<DCAPlan>())) ?? []
        let pending = (try? context.fetch(
            FetchDescriptor<TransactionRecord>(
                predicate: #Predicate { $0.statusRaw == "PENDING" }
            )
        )) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []

        for plan in plans where plan.isActive {
            triggerIfDue(plan: plan, today: today, accounts: accounts, context: context)
        }

        for tx in pending {
            confirmIfRipe(tx: tx, today: today, accounts: accounts, positions: positions, context: context)
        }

        try? context.save()
    }

    private static func triggerIfDue(
        plan: DCAPlan,
        today: Date,
        accounts: [Account],
        context: ModelContext
    ) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        let dueStart = cal.startOfDay(for: plan.nextRunDate)
        guard dueStart <= todayStart else { return }

        if let last = plan.lastRunDate, cal.isDate(last, inSameDayAs: today) {
            return
        }

        guard let source = accounts.first(where: { $0.id == plan.sourceAccountID }) else { return }

        let before = source.cashBalance
        source.cashBalance -= plan.amount
        source.updatedAt = today

        let tx = TransactionRecord(
            tradeDate: today,
            type: .dcaDeduct,
            status: .pending,
            fromAccountID: plan.sourceAccountID,
            toAccountID: plan.targetAccountID,
            fromAccountName: plan.sourceAccountName,
            toAccountName: plan.targetAccountName,
            assetCode: plan.targetAssetCode,
            assetName: plan.targetAssetName,
            amount: plan.amount,
            note: "[\(plan.name)] 自动扣款,等待 T+1 确认",
            dcaPlanID: plan.id,
            sourceBalanceBefore: before,
            sourceBalanceAfter: source.cashBalance
        )
        context.insert(tx)

        plan.lastRunDate = today
        plan.nextRunDate = nextRunDate(after: today, frequency: plan.frequency)
    }

    private static func confirmIfRipe(
        tx: TransactionRecord,
        today: Date,
        accounts: [Account],
        positions: [Position],
        context: ModelContext
    ) {
        guard tx.type == .dcaDeduct, tx.status == .pending else { return }
        let cal = Calendar.current
        let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: tx.tradeDate), to: cal.startOfDay(for: today)).day ?? 0
        // 改为 T+2 自动确认(扣款后第 2 个交易日按当日净值确认份额)
        guard dayDiff >= 2 else { return }

        let targetAccount = accounts.first { $0.id == tx.toAccountID }
        let existingPosition = positions.first { $0.account?.id == tx.toAccountID && $0.assetCode == tx.assetCode }

        let confirmPrice = existingPosition?.lastPrice ?? 1.0
        guard confirmPrice > 0 else { return }
        let confirmedShares = tx.amount / confirmPrice

        tx.statusRaw = TransactionStatus.confirmed.rawValue
        tx.confirmDate = today
        tx.shares = confirmedShares
        tx.price = confirmPrice

        if let pos = existingPosition {
            let newTotal = pos.shares + confirmedShares
            let newAvgCost = (pos.totalCost + tx.amount) / max(newTotal, 0.0001)
            pos.shares = newTotal
            pos.avgCost = newAvgCost
            pos.updatedAt = today
        } else if let target = targetAccount {
            let pos = Position(
                account: target,
                assetCode: tx.assetCode,
                assetName: tx.assetName,
                shares: confirmedShares,
                avgCost: confirmPrice,
                lastPrice: confirmPrice,
                prevClosePrice: confirmPrice,
                weekAgoPrice: confirmPrice,
                monthAgoPrice: confirmPrice,
                yearStartPrice: confirmPrice
            )
            context.insert(pos)
        }
    }

    static func nextRunDate(after date: Date, frequency: DCAFrequency) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return cal.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }

    /// 根据频率 + 周/月内具体日期,计算"从 today 出发的下一个扣款日"。
    /// 用于新建/编辑定投时自动回填日期选择器。
    static func computeNextRun(
        from today: Date = Date(),
        frequency: DCAFrequency,
        dayOfWeek: Int,
        dayOfMonth: Int
    ) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: today) ?? today

        case .weekly, .biweekly:
            let targetCalWeekday = WeekdayPicker.toCalendarWeekday(dayOfWeek)
            let todayWeekday = cal.component(.weekday, from: today)
            var daysUntil = targetCalWeekday - todayWeekday
            if daysUntil <= 0 { daysUntil += 7 }
            return cal.date(byAdding: .day, value: daysUntil, to: today) ?? today

        case .monthly:
            let safeDay = max(1, min(28, dayOfMonth))
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.day = safeDay
            let startOfToday = cal.startOfDay(for: today)
            if let candidate = cal.date(from: comps), candidate > startOfToday {
                return candidate
            }
            if let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.date(from: comps) ?? today) {
                return nextMonth
            }
            return today
        }
    }

    static func manuallyConfirm(tx: TransactionRecord, price: Double, context: ModelContext) {
        guard tx.type == .dcaDeduct, tx.status == .pending, price > 0 else { return }
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        guard let target = accounts.first(where: { $0.id == tx.toAccountID }) else { return }
        let existing = positions.first { $0.account?.id == target.id && $0.assetCode == tx.assetCode }

        let confirmedShares = tx.amount / price
        tx.statusRaw = TransactionStatus.confirmed.rawValue
        tx.confirmDate = Date()
        tx.shares = confirmedShares
        tx.price = price

        if let pos = existing {
            let newTotal = pos.shares + confirmedShares
            let newAvgCost = (pos.totalCost + tx.amount) / max(newTotal, 0.0001)
            pos.shares = newTotal
            pos.avgCost = newAvgCost
            pos.lastPrice = price
            pos.updatedAt = Date()
        } else {
            let pos = Position(
                account: target,
                assetCode: tx.assetCode,
                assetName: tx.assetName,
                shares: confirmedShares,
                avgCost: price,
                lastPrice: price,
                prevClosePrice: price,
                weekAgoPrice: price,
                monthAgoPrice: price,
                yearStartPrice: price
            )
            context.insert(pos)
        }
        try? context.save()
    }
}
