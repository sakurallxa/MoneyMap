import SwiftUI

/// 全局 Toast 状态管理。单例 ObservableObject。
/// 在 ContentView 顶层加 .overlay(ToastOverlayView()) 即可。
@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var current: ToastItem?

    private var dismissTask: Task<Void, Never>?

    enum Kind {
        case success, error, info, network

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .network: return "wifi.exclamationmark"
            }
        }

        var bgColor: Color {
            switch self {
            case .success: return Color(hex: "#1B7F47")
            case .error: return Color(hex: "#E63946")
            case .info: return Color(hex: "#5B8FF9")
            case .network: return Color(hex: "#8E8E93")
            }
        }
    }

    struct ToastItem: Identifiable, Equatable {
        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String?
        let autoDismissAfter: TimeInterval?

        static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    private init() {}

    func success(_ title: String, subtitle: String? = nil) {
        show(.init(kind: .success, title: title, subtitle: subtitle, autoDismissAfter: 2.5))
    }

    func error(_ title: String, subtitle: String? = nil) {
        // error 常驻直到用户操作或下一个 toast 替换
        show(.init(kind: .error, title: title, subtitle: subtitle, autoDismissAfter: nil))
    }

    func info(_ title: String, subtitle: String? = nil) {
        show(.init(kind: .info, title: title, subtitle: subtitle, autoDismissAfter: 2.5))
    }

    func network(_ title: String, subtitle: String? = nil) {
        show(.init(kind: .network, title: title, subtitle: subtitle, autoDismissAfter: 3.0))
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            current = nil
        }
    }

    private func show(_ item: ToastItem) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            current = item
        }
        if let after = item.autoDismissAfter {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
                if Task.isCancelled { return }
                await MainActor.run {
                    if self?.current?.id == item.id { self?.dismiss() }
                }
            }
        }
    }
}
