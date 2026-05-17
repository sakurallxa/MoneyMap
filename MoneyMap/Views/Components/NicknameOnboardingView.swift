import SwiftUI

/// 首次启动引导。两步:
/// ① 欢迎页(¥ logo bloom + feature 列表 + 开始 CTA)
/// ② 称呼输入(称谓三选 + 姓 + 实时问候预览 + 完成)
/// 元素 staggered fade-in + slide-up;logo 用 spring bloom。
struct NicknameOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userNickname") private var userNickname: String = ""
    @AppStorage("didShowNicknameOnboarding") private var didShowOnboarding: Bool = false

    @State private var step: Int = 0
    @State private var welcomeAppeared = false
    @State private var nicknameAppeared = false
    @State private var surname: String = ""
    @State private var gender: Gender = .mister
    @FocusState private var isFocused: Bool

    enum Gender: String, CaseIterable {
        case mister, miss
        var displayName: String {
            switch self {
            case .mister: return "先生"
            case .miss:   return "女士"
            }
        }
    }

    private var nickname: String {
        let s = surname.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        return s + gender.displayName
    }

    private var canFinish: Bool {
        !surname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.Palette.pageBgWarm.ignoresSafeArea()

            if step == 0 {
                welcomePage
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                nicknamePage
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            // 触发欢迎页的 staggered 入场
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                welcomeAppeared = true
            }
        }
    }

    // MARK: - ① 欢迎页

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // ¥ logo (bloom)
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        // 内高光
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0)],
                                    startPoint: .topLeading, endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 28, x: 0, y: 14)

                Text("¥")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .scaleEffect(welcomeAppeared ? 1.0 : 0.6)
            .opacity(welcomeAppeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.05), value: welcomeAppeared)
            .padding(.bottom, 32)

            // 标题
            staggeredItem(delay: 0.20) {
                Text("欢迎使用钱袋")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 12)

            // 副标
            staggeredItem(delay: 0.30) {
                Text("把你的资产、持仓、定投装进一个袋子,\n一眼看清每一笔财富的去向。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 36)

            // feature 列表
            VStack(alignment: .leading, spacing: 14) {
                staggeredItem(delay: 0.42) {
                    featureRow(symbol: "chart.pie", text: "一图看遍所有资产分布")
                }
                staggeredItem(delay: 0.50) {
                    featureRow(symbol: "waveform.path.ecg", text: "累计盈亏与年化一目了然")
                }
                staggeredItem(delay: 0.58) {
                    featureRow(symbol: "calendar", text: "定投自动扣款 · 后台执行")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()

            // 开始 CTA
            staggeredItem(delay: 0.70) {
                Button {
                    advanceToNickname()
                } label: {
                    Text("开始")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 18, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
            }

            staggeredItem(delay: 0.80) {
                Text("所有数据仅保存在你的设备 · 可选 iCloud 同步")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
            .padding(.bottom, 28)
        }
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.accentDark)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Theme.Palette.accent.opacity(0.14))
                )
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - ② 称呼输入页

    private var nicknamePage: some View {
        VStack(spacing: 0) {
            // 顶部:跳过
            HStack {
                Spacer()
                staggeredItem(delay: 0.10, appeared: nicknameAppeared) {
                    Button {
                        skipAndDismiss()
                    } label: {
                        Text("跳过")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // 标题
            staggeredItem(delay: 0.20, appeared: nicknameAppeared) {
                Text("如何称呼您?")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 22)
                    .padding(.top, 40)
            }

            // 姓 + 称谓(单格输入 + segmented)
            staggeredItem(delay: 0.32, appeared: nicknameAppeared) {
                HStack(spacing: 14) {
                    surnameBox
                    genderSegmented
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
            }

            Spacer()

            // 完成 CTA
            staggeredItem(delay: 0.50, appeared: nicknameAppeared) {
                Button {
                    finish()
                } label: {
                    Text("完成")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: canFinish
                                            ? [Theme.Palette.accent, Theme.Palette.accentDark]
                                            : [Theme.Palette.accent.opacity(0.4), Theme.Palette.accentDark.opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Theme.Palette.accent.opacity(canFinish ? 0.45 : 0), radius: 18, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canFinish)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nicknameAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }

    /// 单字大小的姓输入框 — accent 边框 + accent 光晕。
    private var surnameBox: some View {
        TextField("", text: $surname)
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit { finish() }
            .onChange(of: surname) { _, new in
                let trimmed = new.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 1 {
                    surname = String(trimmed.prefix(1))
                }
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.Palette.accent.opacity(0.75), lineWidth: 1.5)
            )
            .shadow(color: Theme.Palette.accent.opacity(0.22), radius: 14, y: 4)
    }

    /// 先生 / 女士 两段 segmented,跟在 surnameBox 后面。
    private var genderSegmented: some View {
        HStack(spacing: 0) {
            ForEach(Gender.allCases, id: \.self) { g in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        gender = g
                    }
                } label: {
                    Text(g.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(gender == g ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            gender == g
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.Palette.accent.opacity(0.16), radius: 12, y: 4)
    }

    // MARK: - 动画 helper

    /// 通用 staggered 入场容器 — fade-in + slide-up,easeOut。
    @ViewBuilder
    private func staggeredItem<Content: View>(
        delay: Double,
        appeared: Bool? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let visible = appeared ?? welcomeAppeared
        content()
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .animation(.easeOut(duration: 0.55).delay(delay), value: visible)
    }

    // MARK: - flow

    private func advanceToNickname() {
        withAnimation(.easeInOut(duration: 0.45)) {
            step = 1
        }
    }

    private func skipAndDismiss() {
        userNickname = "钱袋用户"
        didShowOnboarding = true
        dismiss()
    }

    private func finish() {
        guard canFinish else { return }
        let n = nickname
        userNickname = n.isEmpty ? "钱袋用户" : n
        didShowOnboarding = true
        dismiss()
    }
}
