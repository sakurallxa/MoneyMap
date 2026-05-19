import Foundation
import SwiftUI
import LocalAuthentication

/// 入口生物识别锁(Face ID / Touch ID),系统级 modal 主导所有交互。
///
/// 设计原则:**不在 App 内做重试 / 密码兜底状态机**。iOS 的
/// `.deviceOwnerAuthentication` policy 自带完整行为:
/// - 弹 Face ID → 失败 → 系统 modal 自动给"Try Face ID Again"
/// - 多次失败 → 系统 modal 自动给"Enter Passcode" 进入密码键盘
/// - 用户连续失败到 biometryLockout → 系统强制要求密码
///
/// 因此 App 端唯一职责:
/// - 启动 / 回前台时把 isLocked 置 true
/// - 通过 evaluate() 触发系统 modal
/// - 用户取消时显示"重新验证"按钮兜底
@MainActor
final class BiometricLock: ObservableObject {
    @Published var isLocked: Bool = false
    /// 是否显示"重新验证"按钮 — 仅在用户取消 / 验证失败后才 true。
    /// 默认状态系统弹窗主导,按钮隐藏让 UI 干净。
    @Published var needsManualRetry: Bool = false
    /// 每次 lockIfEnabled 都 +1,Overlay 用 onChange 监听这个 counter 触发认证。
    /// 解决"用户取消后切后台再回来不会自动重新弹"的边角 bug。
    @Published private(set) var lockTriggerCounter: Int = 0
    /// 防止同时多处触发 evaluate(启动 onChange initial + scenePhase 等)
    private var isEvaluating = false

    @AppStorage("biometricLockEnabled") var enabled: Bool = false

    // MARK: - 启动 / 回前台时调用

    /// 若开关为 on,标记需要锁定。Overlay 看到 lockTriggerCounter 变化会自动 evaluate。
    func lockIfEnabled() {
        guard enabled else { return }
        isLocked = true
        needsManualRetry = false
        lockTriggerCounter += 1
    }

    // MARK: - 自动认证(Overlay 内部用)

    /// 触发系统级身份认证。
    /// 用 `.deviceOwnerAuthentication` policy,iOS 会:Face ID → 失败重试 → 自动 fallback 密码。
    func evaluate() {
        guard !isEvaluating else { return }
        isEvaluating = true
        needsManualRetry = false

        let context = LAContext()
        context.localizedFallbackTitle = "使用密码"
        let policy: LAPolicy = .deviceOwnerAuthentication

        var nsError: NSError?
        guard context.canEvaluatePolicy(policy, error: &nsError) else {
            // 设备完全不支持(模拟器没设密码等)→ 降级:放行
            isLocked = false
            isEvaluating = false
            return
        }

        context.evaluatePolicy(policy, localizedReason: "解锁钱袋") { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isEvaluating = false
                if success {
                    self.isLocked = false
                    self.needsManualRetry = false
                } else {
                    // 任何失败 / 用户取消 → 显示"重新验证"按钮,让用户主动再来一次
                    // 系统 modal 内部的"Try Again / Enter Passcode"已经处理了大部分重试场景,
                    // 这个按钮只是用户在系统 modal 完全关闭后的最后兜底入口
                    self.needsManualRetry = true
                }
            }
        }
    }

    // MARK: - Toggle 验证(SettingsView 开关用)

    /// 设置页 Toggle 切换前调用。验证通过才真正改变 enabled。
    func attemptToggle(to newValue: Bool, completion: @escaping (Bool) -> Void) {
        guard newValue != enabled else { completion(true); return }

        let context = LAContext()
        context.localizedFallbackTitle = "使用密码"
        let policy: LAPolicy = .deviceOwnerAuthentication
        var nsError: NSError?
        guard context.canEvaluatePolicy(policy, error: &nsError) else {
            // 设备完全不支持 → 降级:直接通过(让用户在不支持设备上仍能记录偏好)
            enabled = newValue
            completion(true)
            return
        }

        let reason = newValue ? "验证身份以启用 Face ID 锁" : "验证身份以关闭 Face ID 锁"
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.enabled = newValue
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
}

/// 蒙在主界面上的解锁遮罩。视觉与 Hero 卡同源:黑金渐变 + 米→金渐变 logo。
struct BiometricLockOverlay: View {
    @ObservedObject var lock: BiometricLock

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 22/255, green: 20/255, blue: 15/255),
                    Color(red: 34/255, green: 26/255, blue: 17/255),
                    Color(red: 46/255, green: 33/255, blue: 23/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.Bronze.primary.opacity(0.32), .clear],
                center: UnitPoint(x: 0.85, y: 0.15),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Theme.Bronze.primary.opacity(0.4), radius: 18, x: 0, y: 8)

                Text("钱袋")
                    .font(Theme.serif(28, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(Theme.Bronze.creamGoldGradient)

                Rectangle()
                    .fill(Theme.Bronze.goldHairline)
                    .frame(height: 0.6)
                    .frame(maxWidth: 200)

                Text("已加密 · 请验证身份")
                    .font(Theme.serif(13))
                    .kerning(0.4)
                    .foregroundStyle(Color.white.opacity(0.55))

                Spacer()

                // 默认隐藏 — 仅在用户取消或系统 modal 关闭后兜底。
                // 平时整个验证流程由 iOS 系统 modal 主导(Face ID → 失败重试 → 密码 keypad)
                if lock.needsManualRetry {
                    Button {
                        lock.evaluate()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.system(size: 18, weight: .semibold))
                            Text("重新验证")
                                .font(Theme.serif(15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Theme.Bronze.cta)
                                .shadow(color: Theme.Bronze.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 80)
                } else {
                    Color.clear.frame(height: 80).padding(.bottom, 80)
                }
            }
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.25), value: lock.needsManualRetry)
        }
        .transition(.opacity)
        // initial: true 让 view 第一次出现时也触发 → 启动自动唤起 Face ID
        // counter 后续变化(从后台回来重新锁) → 也重新触发,不会卡在静止 overlay
        .onChange(of: lock.lockTriggerCounter, initial: true) { _, _ in
            lock.evaluate()
        }
    }
}
