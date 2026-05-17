import Foundation
import SwiftData

struct BackupSnapshot: Codable {
    let exportedAt: Date
    let appVersion: String
    let schemaVersion: Int
    let accounts: [BackupAccount]
    let positions: [BackupPosition]
    let transactions: [BackupTransaction]
    let dcaPlans: [BackupDCAPlan]
    let dailySnapshots: [BackupDailySnapshot]
    let exchangeRates: [BackupRate]
}

struct BackupAccount: Codable {
    let id: UUID
    let name: String
    let type: String
    let currency: String
    let cashBalance: Double
    let note: String
    let createdAt: Date
    let updatedAt: Date
}

struct BackupPosition: Codable {
    let id: UUID
    let accountID: UUID
    let assetCode: String
    let assetName: String
    let shares: Double
    let avgCost: Double
    let lastPrice: Double
    let prevClosePrice: Double
    let weekAgoPrice: Double
    let monthAgoPrice: Double
    let yearStartPrice: Double
    let updatedAt: Date
}

struct BackupTransaction: Codable {
    let id: UUID
    let tradeDate: Date
    let confirmDate: Date?
    let type: String
    let status: String
    let fromAccountID: UUID?
    let toAccountID: UUID?
    let fromAccountName: String
    let toAccountName: String
    let assetCode: String
    let assetName: String
    let amount: Double
    let shares: Double
    let price: Double
    let fee: Double
    let note: String
    let dcaPlanID: UUID?
    let sourceBalanceBefore: Double
    let sourceBalanceAfter: Double
    let targetBalanceBefore: Double
    let targetBalanceAfter: Double
}

struct BackupDCAPlan: Codable {
    let id: UUID
    let name: String
    let sourceAccountID: UUID
    let sourceAccountName: String
    let targetAccountID: UUID
    let targetAccountName: String
    let targetAssetCode: String
    let targetAssetName: String
    let amount: Double
    let frequency: String
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let nextRunDate: Date
    let lastRunDate: Date?
    let isActive: Bool
    let createdAt: Date
}

struct BackupDailySnapshot: Codable {
    let date: Date
    let totalValueCNY: Double
    let cashValue: Double
    let moneyFundValue: Double
    let fundValue: Double
    let stockAValue: Double
    let stockHKValue: Double
    let stockUSValue: Double
    let pendingValue: Double
    let dailyChange: Double
    let dailyChangePct: Double
}

struct BackupRate: Codable {
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    let date: Date
}

enum DataExportService {
    static let currentSchemaVersion = 1

    static func snapshot(from context: ModelContext) -> BackupSnapshot {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<TransactionRecord>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<DCAPlan>())) ?? []
        let snapshots = (try? context.fetch(FetchDescriptor<DailySnapshot>())) ?? []
        let rates = (try? context.fetch(FetchDescriptor<ExchangeRate>())) ?? []

        return BackupSnapshot(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0",
            schemaVersion: currentSchemaVersion,
            accounts: accounts.map {
                BackupAccount(id: $0.id, name: $0.name, type: $0.typeRaw, currency: $0.currencyRaw,
                              cashBalance: $0.cashBalance, note: $0.note,
                              createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            positions: positions.compactMap { p in
                guard let acc = p.account else { return nil }
                return BackupPosition(
                    id: p.id, accountID: acc.id,
                    assetCode: p.assetCode, assetName: p.assetName,
                    shares: p.shares, avgCost: p.avgCost,
                    lastPrice: p.lastPrice, prevClosePrice: p.prevClosePrice,
                    weekAgoPrice: p.weekAgoPrice, monthAgoPrice: p.monthAgoPrice,
                    yearStartPrice: p.yearStartPrice, updatedAt: p.updatedAt
                )
            },
            transactions: transactions.map {
                BackupTransaction(
                    id: $0.id, tradeDate: $0.tradeDate, confirmDate: $0.confirmDate,
                    type: $0.typeRaw, status: $0.statusRaw,
                    fromAccountID: $0.fromAccountID, toAccountID: $0.toAccountID,
                    fromAccountName: $0.fromAccountName, toAccountName: $0.toAccountName,
                    assetCode: $0.assetCode, assetName: $0.assetName,
                    amount: $0.amount, shares: $0.shares, price: $0.price, fee: $0.fee,
                    note: $0.note, dcaPlanID: $0.dcaPlanID,
                    sourceBalanceBefore: $0.sourceBalanceBefore,
                    sourceBalanceAfter: $0.sourceBalanceAfter,
                    targetBalanceBefore: $0.targetBalanceBefore,
                    targetBalanceAfter: $0.targetBalanceAfter
                )
            },
            dcaPlans: plans.map {
                BackupDCAPlan(
                    id: $0.id, name: $0.name,
                    sourceAccountID: $0.sourceAccountID, sourceAccountName: $0.sourceAccountName,
                    targetAccountID: $0.targetAccountID, targetAccountName: $0.targetAccountName,
                    targetAssetCode: $0.targetAssetCode, targetAssetName: $0.targetAssetName,
                    amount: $0.amount, frequency: $0.frequencyRaw,
                    dayOfWeek: $0.dayOfWeek, dayOfMonth: $0.dayOfMonth,
                    nextRunDate: $0.nextRunDate, lastRunDate: $0.lastRunDate,
                    isActive: $0.isActive, createdAt: $0.createdAt
                )
            },
            dailySnapshots: snapshots.map {
                BackupDailySnapshot(
                    date: $0.date, totalValueCNY: $0.totalValueCNY,
                    cashValue: $0.cashValue, moneyFundValue: $0.moneyFundValue,
                    fundValue: $0.fundValue, stockAValue: $0.stockAValue,
                    stockHKValue: $0.stockHKValue, stockUSValue: $0.stockUSValue,
                    pendingValue: $0.pendingValue, dailyChange: $0.dailyChange,
                    dailyChangePct: $0.dailyChangePct
                )
            },
            exchangeRates: rates.map {
                BackupRate(fromCurrency: $0.fromCurrency, toCurrency: $0.toCurrency,
                           rate: $0.rate, date: $0.date)
            }
        )
    }

    static func exportJSON(from context: ModelContext) -> Data? {
        let snap = snapshot(from: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snap)
    }

    /// 持仓快照 CSV——只导出当前持仓 + 估值,适合用 Excel/Numbers 查看。
    static func exportPositionsCSV(from context: ModelContext, rates: [String: Double]) -> Data? {
        let positions = (try? context.fetch(FetchDescriptor<Position>())) ?? []
        var lines: [String] = []
        lines.append("\u{FEFF}所属账户,资产代码,资产名称,持有份额,平均成本,当前价格,币种,市值(原币),市值(CNY),浮盈(CNY),浮盈率")
        for p in positions {
            guard let acc = p.account else { continue }
            let fx = rates[p.effectiveCurrency.rawValue] ?? 1.0
            let mv = p.marketValue
            let mvCNY = mv * fx
            let pnlCNY = p.unrealizedPnL * fx
            let pnlPct = p.unrealizedPnLPercent
            let row = [
                csv(acc.name),
                csv(p.assetCode),
                csv(p.assetName),
                String(format: "%.4f", p.shares),
                String(format: "%.4f", p.avgCost),
                String(format: "%.4f", p.lastPrice),
                p.effectiveCurrency.rawValue,
                String(format: "%.2f", mv),
                String(format: "%.2f", mvCNY),
                String(format: "%.2f", pnlCNY),
                String(format: "%.2f", pnlPct) + "%"
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    private static func csv(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
