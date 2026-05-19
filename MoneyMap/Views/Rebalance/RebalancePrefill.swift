import Foundation

/// 再平衡 / 调试入口 → 交易表单的预填载荷。
/// 之前住在已废弃的 AddTransactionSheet.swift 里,迁出来给 TransactionFormView 用。
struct RebalancePrefill: Identifiable {
    let id = UUID()
    let action: TradeAction
    let assetClass: AssetClass
    let amount: Double
}

enum TradeAction: String {
    case buy = "BUY"
    case sell = "SELL"

    var displayName: String {
        switch self {
        case .buy: return "买入"
        case .sell: return "卖出"
        }
    }

    /// 映射到 TransactionFormView 用的 form type。
    /// 买入默认走 buyExisting(再平衡场景下用户已经持有该资产),不强制 buyNew。
    var formType: TransactionFormType {
        switch self {
        case .buy: return .buyExisting
        case .sell: return .sell
        }
    }
}
