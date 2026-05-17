import SwiftUI

/// 首次启动引导用户输入姓氏 + 选择称呼。组合后保存为「陈先生」/「李女士」。
struct NicknameOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userNickname") private var userNickname: String = ""
    @AppStorage("didShowNicknameOnboarding") private var didShowOnboarding: Bool = false

    @State private var surname: String = ""
    @State private var gender: Gender = .mister
    @FocusState private var isFocused: Bool

    enum Gender: String, CaseIterable {
        case mister, miss
        var displayName: String {
            switch self {
            case .mister: return "先生"
            case .miss: return "女士"
            }
        }
    }

    private var preview: String {
        let s = surname.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return "陈\(gender.displayName)" }
        return s + gender.displayName
    }

    private var canSave: Bool {
        !surname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 顶部图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.accent, Theme.Palette.accentDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)

            Text("欢迎来到钱袋")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 4)

            Text("我们怎么称呼你?")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            // 预览
            Text(preview)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.accentDark)
                .padding(.bottom, 28)

            // 输入区
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("你的姓")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("如:陈", text: $surname)
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.trailing)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                        .frame(maxWidth: 120)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                Picker("称呼", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                save()
            } label: {
                Text("开始使用")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(canSave ? Theme.Palette.accent : Theme.Palette.accent.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Button {
                userNickname = "钱袋用户"
                didShowOnboarding = true
                dismiss()
            } label: {
                Text("以后再说")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private func save() {
        guard canSave else { return }
        userNickname = preview
        didShowOnboarding = true
        dismiss()
    }
}
