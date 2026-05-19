import SwiftUI

/// 设置页内编辑昵称(姓 + 称呼)。
struct NicknameEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userNickname") private var userNickname: String = ""

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
        if s.isEmpty { return "X\(gender.displayName)" }
        return s + gender.displayName
    }

    private var canSave: Bool {
        !surname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 预览
                VStack(spacing: 10) {
                    Text("怎么称呼您?")
                        .font(Theme.serif(13))
                        .foregroundStyle(.secondary)
                    Text(preview)
                        .font(Theme.serif(38, weight: .bold))
                        .foregroundStyle(Theme.Palette.accentDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("您的姓")
                            .font(Theme.serif(13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("", text: $surname)
                            .font(Theme.serif(17, weight: .semibold))
                            .multilineTextAlignment(.trailing)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { save() }
                            .frame(maxWidth: 140)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    // 自绘 segmented — 系统 Picker(.segmented) 用 UISegmentedControl,
                    // 文字不走思源宋体。这里用思源宋体 + 铜色选中态,与项目语言统一。
                    HStack(spacing: 8) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Button {
                                gender = g
                            } label: {
                                Text(g.displayName)
                                    .font(Theme.serif(14, weight: .semibold))
                                    .foregroundStyle(gender == g ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(gender == g ? Theme.Palette.accent : Color.black.opacity(0.045))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("编辑昵称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.Palette.accentDark)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(canSave ? Theme.Palette.accentDark : Theme.Palette.accentDark.opacity(0.35))
                        .disabled(!canSave)
                }
            }
            .onAppear {
                seedFromExisting()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        // 直接 large — 配合 onAppear 自动唤起键盘,避免"半屏 → 大屏"的 resize 跳变。
        // 之前用 [.medium, .large] 默认落 medium,0.3s 后 isFocused = true 触发键盘,
        // iOS 自动把 detent 拔到 large,视觉上是个明显的卡顿。
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func seedFromExisting() {
        let n = userNickname.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, n != "钱袋用户" else { return }
        if n.hasSuffix("先生") {
            gender = .mister
            surname = String(n.dropLast(2))
        } else if n.hasSuffix("女士") {
            gender = .miss
            surname = String(n.dropLast(2))
        } else {
            surname = String(n.prefix(1))
        }
    }

    private func save() {
        guard canSave else { return }
        userNickname = preview
        ToastManager.shared.success("已更新昵称")
        dismiss()
    }
}
