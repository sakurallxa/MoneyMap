import Foundation
import SwiftData

struct AssetBreakdown {
    var cash: Double = 0
    var moneyFund: Double = 0
    var fund: Double = 0
    var stockA: Double = 0
    var stockHK: Double = 0
    var stockUS: Double = 0
    var gold: Double = 0
    var pending: Double = 0

    var total: Double {
        cash + moneyFund + fund + stockA + stockHK + stockUS + gold + pending
    }

    var segments: [(label: String, value: Double, colorHex: String)] {
        [
            ("现金", cash, "#5B8FF9"),
            ("货基", moneyFund, "#7B68EE"),
            ("基金", fund, "#F4B860"),
            ("A 股", stockA, "#E63946"),
            ("港股", stockHK, "#2A9D8F"),
            ("美股", stockUS, "#1ABC9C"),
            ("黄金", gold, "#D4AF37"),
            ("在途", pending, "#94A3B8")
        ].filter { $0.value > 0.01 }
    }
}

struct ValuationService {
    static func currentBreakdown(
        accounts: [Account],
        positions: [Position],
        pendingTransactions: [TransactionRecord],
        rates: [String: Double] = ["HKD": 0.92, "USD": 7.18, "CNY": 1.0]
    ) -> AssetBreakdown {
        var breakdown = AssetBreakdown()

        for acc in accounts {
            let rate = rates[acc.currency.rawValue] ?? 1.0
            let valueCNY = acc.cashBalance * rate
            switch acc.type {
            case .cash:
                breakdown.cash += valueCNY
            case .moneyFund:
                breakdown.moneyFund += valueCNY
            case .fundApp, .brokerA, .brokerHK, .brokerUS, .brokerHKUS, .goldDeposit, .goldPhysical:
                breakdown.cash += valueCNY
            }
        }

        for pos in positions {
            guard let acc = pos.account else { continue }
            let rate = rates[pos.effectiveCurrency.rawValue] ?? 1.0
            let mvCNY = pos.marketValue * rate

            switch pos.assetClass {
            case .gold:
                breakdown.gold += mvCNY
            case .fund:
                breakdown.fund += mvCNY
            case .stockA:
                breakdown.stockA += mvCNY
            case .stockHK:
                breakdown.stockHK += mvCNY
            case .stockUS:
                breakdown.stockUS += mvCNY
            case .cash:
                breakdown.cash += mvCNY
            case .moneyFund:
                breakdown.moneyFund += mvCNY
            }
            _ = acc
        }

        for tx in pendingTransactions where tx.status == .pending {
            breakdown.pending += tx.amount
        }

        return breakdown
    }

    static func dailyChange(
        snapshots: [DailySnapshot]
    ) -> (delta: Double, pct: Double) {
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return (0, 0) }
        let latest = sorted[sorted.count - 1]
        let prev = sorted[sorted.count - 2]
        let delta = latest.totalValueCNY - prev.totalValueCNY
        let pct = prev.totalValueCNY > 0 ? delta / prev.totalValueCNY * 100 : 0
        return (delta, pct)
    }
}
