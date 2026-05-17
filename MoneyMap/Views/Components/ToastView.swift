import SwiftUI

/// 全局 Toast 渲染层。挂在 ContentView 的 .overlay 里。
struct ToastOverlayView: View {
    @ObservedObject private var manager = ToastManager.shared

    var body: some View {
        ZStack {
            if let item = manager.current {
                VStack {
                    Spacer()
                    toastCard(item)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: manager.current?.id)
    }

    @ViewBuilder
    private func toastCard(_ item: ToastManager.ToastItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.kind.bgColor)
                Image(systemName: item.kind.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let sub = item.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.autoDismissAfter == nil {
                // error 等常驻 toast — 提供关闭按钮
                Button {
                    manager.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 40/255, green: 40/255, blue: 48/255).opacity(0.92))
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        .gesture(
            DragGesture()
                .onEnded { v in
                    if abs(v.translation.height) > 30 {
                        manager.dismiss()
                    }
                }
        )
    }
}
