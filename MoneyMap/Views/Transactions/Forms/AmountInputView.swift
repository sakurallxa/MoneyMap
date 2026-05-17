import SwiftUI

/// 表单顶部的居中大金额输入。
/// 颜色随类型变化(红/绿/中性),带闪烁光标。
struct AmountInputView: View {
    let type: TransactionFormType
    @Binding var amountText: String
    @State private var cursorOn = true
    @FocusState private var isFocused: Bool

    private var sign: String {
        switch type.moneyDirection {
        case .out: return "−"
        case .in: return "+"
        case .neutral: return ""
        }
    }

    private var color: Color {
        switch type.moneyDirection {
        case .out: return .pnlPositive
        case .in: return .pnlNegative
        case .neutral: return .primary
        }
    }

    private var amountParts: (intPart: String, decPart: String) {
        let raw = amountText.isEmpty ? "0" : amountText
        let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let intStr = parts.first ?? "0"
        let decStr = parts.count > 1 ? parts[1] : ""
        return (formatGrouping(intStr), decStr)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("金额")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(.tertiary)

            ZStack {
                // 可视层 — 不接收点击,让 tap 穿透到底下的 TextField
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if !sign.isEmpty {
                        Text(sign)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(color.opacity(0.6))
                    }
                    Text("¥")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(color.opacity(0.85))

                    Text(amountParts.intPart)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .kerning(-2)
                        .foregroundStyle(color)

                    if !amountParts.decPart.isEmpty {
                        Text(".\(amountParts.decPart)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(color.opacity(0.55))
                            .padding(.bottom, 4)
                    }

                    Rectangle()
                        .fill(Theme.Palette.accent)
                        .frame(width: 2, height: 38)
                        .opacity(cursorOn && isFocused ? 1 : 0)
                        .padding(.leading, 2)
                }
                .monospacedDigit()
                .allowsHitTesting(false)

                // 真实 TextField 在最上层,几乎透明,接收键盘输入
                TextField("", text: $amountText)
                    .keyboardType(.decimalPad)
                    .opacity(0.001)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .frame(minHeight: 70)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            Text(isFocused ? "数字键盘已打开 · 输入完成可点旁边任意处收起" : "点击数字输入 · 自动从行情同步价格")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .onAppear {
            // 进入表单时光标闪烁开始,自动 focus
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorOn = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private func formatGrouping(_ s: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        if let n = Double(s) {
            return f.string(from: NSNumber(value: n)) ?? s
        }
        return s
    }
}
