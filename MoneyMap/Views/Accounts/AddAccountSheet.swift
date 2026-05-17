import SwiftUI
import SwiftData

struct AddAccountSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var currency: CurrencyCode = .cny
    @State private var cashBalanceText = ""
    @State private var note = ""
    @FocusState private var isNameFocused: Bool

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private let typeOrder: [AccountType] = [
        .cash, .moneyFund, .fundApp, .brokerA, .brokerHK, .brokerUS, .goldDeposit, .goldPhysical
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    nameHero
                    typeGrid
                    basicCard
                    noteCard
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFocused = true
                }
            }
        }
    }

    private var nameHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("账户名称")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)
            TextField("如:招商银行卡 / 支付宝基金", text: $name)
                .font(.system(size: 22, weight: .bold))
                .focused($isNameFocused)
                .submitLabel(.done)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var typeGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("账户类型")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(typeOrder, id: \.self) { t in
                    typeCard(t)
                }
            }
        }
    }

    private func typeCard(_ t: AccountType) -> some View {
        let selected = type == t
        let color = typeColor(t)
        return Button {
            type = t
            // 港股 → HKD,美股 → USD,黄金 → CNY
            switch t {
            case .brokerHK: currency = .hkd
            case .brokerUS: currency = .usd
            case .goldDeposit, .goldPhysical: currency = .cny
            default: break
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(selected ? 0.22 : 0.12))
                    Image(systemName: t.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 36, height: 36)
                Text(t.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? color.opacity(0.10) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? color : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: selected ? color.opacity(0.25) : .black.opacity(0.04), radius: selected ? 12 : 6, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var basicCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("基础信息")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)

            HStack {
                Text("币种")
                    .font(.system(size: 14))
                Spacer()
                Picker("币种", selection: $currency) {
                    ForEach(CurrencyCode.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            // 仅现金/货基账户才需要初始余额;投资类账户的余额由持仓决定。
            if !type.isInvestment {
                Divider().opacity(0.4)

                HStack {
                    Text("初始余额")
                        .font(.system(size: 14))
                    Spacer()
                    HStack(spacing: 1) {
                        Text(currency.symbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $cashBalanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .fixedSize()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注(可选)")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)
            TextField("用途说明 · 如「工资卡 / 定投扣款源」", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .cardElevation()
    }

    private func typeColor(_ t: AccountType) -> Color {
        switch t {
        case .cash: return Color(hex: "#5B8FF9")
        case .moneyFund: return Color(hex: "#7B68EE")
        case .fundApp: return Color(hex: "#F4B860")
        case .brokerA: return Color(hex: "#E63946")
        case .brokerHK: return Color(hex: "#2A9D8F")
        case .brokerUS: return Color(hex: "#1ABC9C")
        case .brokerHKUS: return Color(hex: "#2A9D8F")
        case .goldDeposit, .goldPhysical: return Color(hex: "#D4AF37")
        }
    }

    private func save() {
        // 投资类账户的初始余额恒为 0(持仓由后续买入/添加生成)
        let balance = type.isInvestment ? 0 : (Double(cashBalanceText) ?? 0)
        let acc = Account(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            currency: currency,
            cashBalance: balance,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        context.insert(acc)
        do {
            try context.save()
            ToastManager.shared.success("已添加账户「\(acc.name)」")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
