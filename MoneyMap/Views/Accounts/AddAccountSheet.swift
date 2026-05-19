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
            .toolbarBackground(Theme.Palette.pageBgWarm, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.Palette.accentDark)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(canSave ? Theme.Palette.accentDark : Theme.Palette.warmIconDisabled)
                        .disabled(!canSave)
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
                .font(Theme.TypeToken.eyebrow())
                .kerning(Theme.TypeToken.eyebrowKerning)
                .foregroundStyle(.tertiary)
            TextField("如:招商银行卡 / 支付宝基金", text: $name)
                .font(Theme.serif(22, weight: .bold))
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
                .font(Theme.TypeToken.eyebrow())
                .kerning(Theme.TypeToken.eyebrowKerning)
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
            // 切换类型时,币种总是同步到该类型的默认币种 —
            // 港股→HKD / 美股→USD / 其他→CNY。
            currency = t.defaultCurrency
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
                    .font(Theme.serif(11, weight: .semibold))
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
                .font(Theme.TypeToken.eyebrow())
                .kerning(Theme.TypeToken.eyebrowKerning)
                .foregroundStyle(.tertiary)

            HStack {
                Text("币种")
                    .font(Theme.serif(14))
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
                        .font(Theme.serif(14))
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
                .font(Theme.TypeToken.eyebrow())
                .kerning(Theme.TypeToken.eyebrowKerning)
                .foregroundStyle(.tertiary)
            TextField("用途说明 · 如「工资卡 / 定投扣款源」", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(Theme.serif(14))
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
        case .cash: return Theme.Palette.segmentCash
        case .moneyFund: return Theme.Palette.segmentMoneyFund
        case .fundApp: return Theme.Palette.segmentFund
        case .brokerA: return Theme.Palette.segmentStockA
        case .brokerHK: return Theme.Palette.segmentStockHK
        case .brokerUS: return Theme.Palette.segmentStockUS
        case .brokerHKUS: return Theme.Palette.segmentStockHK
        case .goldDeposit, .goldPhysical: return Theme.Palette.segmentGold
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
            SnapshotService.recordToday(context: context)
            ToastManager.shared.success("已添加账户「\(acc.name)」")
            dismiss()
        } catch {
            ToastManager.shared.error("保存失败", subtitle: error.localizedDescription)
        }
    }
}
