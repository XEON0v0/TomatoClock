import SwiftUI
import Charts

/// 7 天柱状图
struct WeeklyChartView: View {

    let data: [DayData]
    let dailyGoal: Int

    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let label: String        // "周一" / "7/6"
        let count: Int
        let isToday: Bool
    }

    var body: some View {
        Chart(data) { d in
            BarMark(
                x: .value("日", d.label),
                y: .value("番茄数", d.count)
            )
            .foregroundStyle(barColor(for: d))
            .cornerRadius(4)
            .annotation(position: .top, alignment: .center) {
                if d.count > 0 {
                    Text("\(d.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: data.map { $0.label }) { value in
                AxisValueLabel()
            }
        }
        .frame(height: 140)
    }

    private func barColor(for d: DayData) -> Color {
        if d.isToday {
            return Color(red: 1.0, green: 0.42, blue: 0.42) // 专注色高亮
        }
        return Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.45)
    }
}
