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
        if s.isEmpty { return "陈\(gender.displayName)" }
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
                    Text("我们怎么称呼你?")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(preview)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.accentDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 24)

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
                            .frame(maxWidth: 140)
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
            }
            .background(Theme.Palette.pageBgWarm.ignoresSafeArea())
            .navigationTitle("编辑昵称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSave ? Theme.Palette.accentDark : .secondary)
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
        .presentationDetents([.medium, .large])
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
