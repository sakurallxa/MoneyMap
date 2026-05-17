import SwiftUI

/// 用于「+」按钮入口的全屏类型选择页。
/// 选完类型后 push 到对应 form。
enum TransactionFormType: Hashable {
    case buyExisting     // 加仓
    case buyNew          // 首次买入
    case sell            // 卖出
    case dividend        // 分红
    case deposit         // 入金
    case withdraw        // 出金
    case transfer        // 转账

    var title: String {
        switch self {
        case .buyExisting: return "加仓"
        case .buyNew: return "首次买入"
        case .sell: return "卖出"
        case .dividend: return "分红"
        case .deposit: return "入金"
        case .withdraw: return "出金"
        case .transfer: return "转账"
        }
    }

    var subtitle: String {
        switch self {
        case .buyExisting: return "已有持仓继续买入"
        case .buyNew: return "新资产 · 自动建仓"
        case .sell: return "减仓或清仓"
        case .dividend: return "基金分红、股票派息"
        case .deposit: return "往账户转入"
        case .withdraw: return "从账户提取"
        case .transfer: return "在你的账户之间挪钱"
        }
    }

    var icon: String {
        switch self {
        case .buyExisting: return "arrow.down.left"
        case .buyNew: return "plus"
        case .sell: return "arrow.up.right"
        case .dividend: return "gift.fill"
        case .deposit: return "arrow.down"
        case .withdraw: return "arrow.up"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .buyExisting, .buyNew: return .pnlPositive
        case .sell: return .pnlNegative
        case .dividend: return Color(hex: "#E0A82E")
        case .deposit: return .pnlNegative
        case .withdraw: return Color(hex: "#8E8E93")
        case .transfer: return Color(hex: "#7B68EE")
        }
    }

    /// 资金方向 — 用于表单大金额输入的符号 / 颜色 / CTA 文案
    var moneyDirection: MoneyDirection {
        switch self {
        case .buyExisting, .buyNew, .withdraw: return .out  // 钱出去
        case .sell, .dividend, .deposit: return .in        // 钱进来
        case .transfer: return .neutral                     // 不影响 P&L
        }
    }

    enum MoneyDirection {
        case `in`, out, neutral
    }
}

struct TransactionTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickerNav = NavigationPath()

    var body: some View {
        NavigationStack(path: $pickerNav) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("记一笔")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    primaryGrid
                    flowList

                    Spacer(minLength: 30)
                }
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(todayLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(for: TransactionFormType.self) { type in
                TransactionFormView(type: type) {
                    dismiss()
                }
            }
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: Date())
    }

    private var primaryGrid: some View {
        let primary: [TransactionFormType] = [.buyExisting, .buyNew, .sell, .dividend]
        return VStack(spacing: 0) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(primary, id: \.self) { t in
                    primaryCard(for: t)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func primaryCard(for type: TransactionFormType) -> some View {
        Button {
            pickerNav.append(type)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Circle()
                        .fill(type.color.opacity(0.06))
                        .frame(width: 80, height: 80)
                        .offset(x: 110, y: -20)

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [type.color.opacity(0.22), type.color.opacity(0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(type.color)
                    }
                    .frame(width: 40, height: 40)
                }
                .frame(height: 80)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(type.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .cardElevation()
        }
        .buttonStyle(.plain)
    }

    private var flowList: some View {
        let flow: [TransactionFormType] = [.deposit, .withdraw, .transfer]
        return VStack(alignment: .leading, spacing: 8) {
            Text("资金流动")
                .font(.system(size: 12, weight: .semibold))
                .kerning(1)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)

            VStack(spacing: 0) {
                ForEach(Array(flow.enumerated()), id: \.element) { idx, t in
                    Button {
                        pickerNav.append(t)
                    } label: {
                        flowRow(for: t)
                    }
                    .buttonStyle(.plain)
                    if idx < flow.count - 1 {
                        Divider().opacity(0.4).padding(.leading, 64)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .cardElevation()
            .padding(.horizontal, 14)
        }
    }

    private func flowRow(for type: TransactionFormType) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(type.color.opacity(0.14))
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(type.color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(type.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
