import SwiftUI

/// 资产分布饼图 — 环形分段,每段对应一类资产。
/// 中心可叠加标签(共 N 类 / 总值)。
struct DonutChart: View {
    let segments: [DonutSegment]
    var thickness: CGFloat = 16
    var gapDegrees: Double = 1.5

    struct DonutSegment: Identifiable {
        let id: String
        let value: Double
        let color: Color

        init(id: String, value: Double, color: Color) {
            self.id = id
            self.value = max(0, value)
            self.color = color
        }
    }

    private var total: Double {
        max(segments.reduce(0) { $0 + $1.value }, 0.0001)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - thickness / 2

            ZStack {
                ForEach(arcAngles(), id: \.id) { arc in
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: size / 2, y: size / 2),
                            radius: radius,
                            startAngle: arc.start,
                            endAngle: arc.end,
                            clockwise: false
                        )
                    }
                    .stroke(arc.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private struct Arc: Identifiable {
        let id: String
        let start: Angle
        let end: Angle
        let color: Color
    }

    private func arcAngles() -> [Arc] {
        guard !segments.isEmpty else { return [] }
        var arcs: [Arc] = []
        var currentDeg: Double = -90 // start at top
        for s in segments {
            let portion = s.value / total
            let span = max(portion * 360 - gapDegrees, 0.1)
            arcs.append(Arc(
                id: s.id,
                start: .degrees(currentDeg),
                end: .degrees(currentDeg + span),
                color: s.color
            ))
            currentDeg += portion * 360
        }
        return arcs
    }
}
