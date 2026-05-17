import SwiftUI

/// 极简折线 sparkline,用于 Hero / 总资产卡的装饰展示。
/// 自动 normalize 数据到 0..1 区间;末端可选发光圆点。
struct MiniSparkline: View {
    let values: [Double]
    var lineColor: Color = .accentColor
    var fillGradient: Gradient? = nil
    var lineWidth: CGFloat = 1.8
    var showEndDot: Bool = false
    var glow: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = computePoints(in: CGSize(width: w, height: h))

            ZStack {
                if let grad = fillGradient {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: h))
                        for p in points { path.addLine(to: p) }
                        if let last = points.last {
                            path.addLine(to: CGPoint(x: last.x, y: h))
                        }
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(gradient: grad, startPoint: .top, endPoint: .bottom))
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                if showEndDot, let last = points.last {
                    if glow {
                        Circle()
                            .fill(lineColor.opacity(0.35))
                            .frame(width: 18, height: 18)
                            .blur(radius: 5)
                            .position(last)
                    }
                    Circle()
                        .fill(lineColor)
                        .frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
    }

    private func computePoints(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else {
            return [CGPoint(x: 0, y: size.height / 2),
                    CGPoint(x: size.width, y: size.height / 2)]
        }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 0.0001)
        let stepX = size.width / CGFloat(values.count - 1)
        let pad: CGFloat = 4
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let normalized = (v - minV) / range
            let y = size.height - pad - CGFloat(normalized) * (size.height - 2 * pad)
            return CGPoint(x: x, y: y)
        }
    }
}
