import Foundation
import SwiftData

enum DataImportError: Error, LocalizedError {
    case unsupportedFormat
    case schemaTooNew
    case parseFailed
    case empty

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "文件格式不识别,请选择本应用导出的 JSON 备份"
        case .schemaTooNew: return "备份来自更高版本的应用,请先升级"
        case .parseFailed: return "备份文件解析失败"
        case .empty: return "备份内容为空"
        }
    }
}

enum DataImportService {
    @MainActor
    static func importJSON(data: Data, context: ModelContext, replace: Bool) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snap = try? decoder.decode(BackupSnapshot.self, from: data) else {
            throw DataImportError.parseFailed
        }
        guard snap.schemaVersion <= DataExportService.currentSchemaVersion else {
            throw DataImportError.schemaTooNew
        }
        guard !snap.accounts.isEmpty else { throw DataImportError.empty }

        if replace {
            try? context.delete(model: Account.self)
            try? context.delete(model: Position.self)
            try? context.delete(model: TransactionRecord.self)
            try? context.delete(model: DCAPlan.self)
            try? context.delete(model: DailySnapshot.self)
            try? context.delete(model: ExchangeRate.self)
        }

        var accountByID: [UUID: Account] = [:]
        for a in snap.accounts {
            let acc = Account(
                id: a.id,
                name: a.name,
                type: AccountType(rawValue: a.type) ?? .cash,
                currency: CurrencyCode(rawValue: a.currency) ?? .cny,
                cashBalance: a.cashBalance,
                note: a.note
            )
            acc.createdAt = a.createdAt
            acc.updatedAt = a.updatedAt
            context.insert(acc)
            accountByID[a.id] = acc
        }

        for p in snap.positions {
            guard let acc = accountByID[p.accountID] else { continue }
            let pos = Position(
                id: p.id, account: acc,
                assetCode: p.assetCode, assetName: p.assetName,
                shares: p.shares, avgCost: p.avgCost, lastPrice: p.lastPrice,
                prevClosePrice: p.prevClosePrice, weekAgoPrice: p.weekAgoPrice,
                monthAgoPrice: p.monthAgoPrice, yearStartPrice: p.yearStartPrice
            )
            pos.updatedAt = p.updatedAt
            context.insert(pos)
        }

        for t in snap.transactions {
            let tx = TransactionRecord(
                id: t.id, tradeDate: t.tradeDate,
                type: TransactionType(rawValue: t.type) ?? .buyFund,
                status: TransactionStatus(rawValue: t.status) ?? .completed,
                fromAccountID: t.fromAccountID, toAccountID: t.toAccountID,
                fromAccountName: t.fromAccountName, toAccountName: t.toAccountName,
                assetCode: t.assetCode, assetName: t.assetName,
                amount: t.amount, shares: t.shares, price: t.price, fee: t.fee,
                note: t.note, dcaPlanID: t.dcaPlanID,
                sourceBalanceBefore: t.sourceBalanceBefore,
                sourceBalanceAfter: t.sourceBalanceAfter,
                targetBalanceBefore: t.targetBalanceBefore,
                targetBalanceAfter: t.targetBalanceAfter
            )
            tx.confirmDate = t.confirmDate
            context.insert(tx)
        }

        for plan in snap.dcaPlans {
            let p = DCAPlan(
                id: plan.id, name: plan.name,
                sourceAccountID: plan.sourceAccountID, sourceAccountName: plan.sourceAccountName,
                targetAccountID: plan.targetAccountID, targetAccountName: plan.targetAccountName,
                targetAssetCode: plan.targetAssetCode, targetAssetName: plan.targetAssetName,
                amount: plan.amount, frequency: DCAFrequency(rawValue: plan.frequency) ?? .weekly,
                nextRunDate: plan.nextRunDate,
                dayOfWeek: plan.dayOfWeek ?? 1,
                dayOfMonth: plan.dayOfMonth ?? 1,
                isActive: plan.isActive
            )
            p.lastRunDate = plan.lastRunDate
            p.createdAt = plan.createdAt
            context.insert(p)
        }

        for snapItem in snap.dailySnapshots {
            let d = DailySnapshot(
                date: snapItem.date, totalValueCNY: snapItem.totalValueCNY,
                cashValue: snapItem.cashValue, moneyFundValue: snapItem.moneyFundValue,
                fundValue: snapItem.fundValue, stockAValue: snapItem.stockAValue,
                stockHKValue: snapItem.stockHKValue, stockUSValue: snapItem.stockUSValue,
                pendingValue: snapItem.pendingValue, dailyChange: snapItem.dailyChange,
                dailyChangePct: snapItem.dailyChangePct
            )
            context.insert(d)
        }

        for r in snap.exchangeRates {
            let rate = ExchangeRate(
                from: CurrencyCode(rawValue: r.fromCurrency) ?? .hkd,
                to: CurrencyCode(rawValue: r.toCurrency) ?? .cny,
                rate: r.rate,
                date: r.date
            )
            context.insert(rate)
        }

        try? context.save()
    }
}
