import Foundation

struct RebalanceItem: Identifiable {
    let assetClass: AssetClass
    let currentValue: Double
    let currentPercent: Double
    let targetPercent: Double
    let targetValue: Double

    var id: String { assetClass.rawValue }
    var deviationPercent: Double { currentPercent - targetPercent }
    var actionAmount: Double { targetValue - currentValue }

    var isSignificant: Bool {
        abs(deviationPercent) >= 1.5 || abs(actionAmount) >= 500
    }

    enum Action {
        case buy, sell, hold
    }

    var action: Action {
        if !isSignificant { return .hold }
        return actionAmount > 0 ? .buy : .sell
    }
}

enum RebalanceService {
    /// 默认建议(平衡型)。第一次进入再平衡时种子用。
    static func defaultTargets() -> [AssetClass: Double] {
        RebalanceModel.balanced.presetTargets
    }

    static func compute(
        breakdown: AssetBreakdown,
        targets: [TargetAllocation]
    ) -> [RebalanceItem] {
        let total = max(breakdown.total, 0.01)
        let map: [AssetClass: Double] = Dictionary(
            uniqueKeysWithValues: targets.map { ($0.assetClass, $0.targetPercent) }
        )

        var items: [RebalanceItem] = []
        for cls in AssetClass.allCases {
            let current = currentValue(for: cls, breakdown: breakdown)
            let currentPct = current / total * 100
            let targetPct = map[cls] ?? 0
            let targetValue = total * targetPct / 100
            items.append(RebalanceItem(
                assetClass: cls,
                currentValue: current,
                currentPercent: currentPct,
                targetPercent: targetPct,
                targetValue: targetValue
            ))
        }
        return items
    }

    static func currentValue(for cls: AssetClass, breakdown: AssetBreakdown) -> Double {
        switch cls {
        case .cash: return breakdown.cash
        case .moneyFund: return breakdown.moneyFund
        case .fund: return breakdown.fund
        case .stockA: return breakdown.stockA
        case .stockHK: return breakdown.stockHK
        case .stockUS: return breakdown.stockUS
        case .gold: return breakdown.gold
        }
    }

    /// 整体偏离度——所有类别 |偏离百分比| 的加权平均,反映组合"跑偏"程度。
    /// 0 表示完全匹配,数字越大越需要调整。
    static func overallDeviation(items: [RebalanceItem]) -> Double {
        let totalAbs = items.reduce(0.0) { $0 + abs($1.deviationPercent) }
        return totalAbs / 2  // /2 because deviations are symmetric (over + under)
    }
}
