import SwiftUI
import SwiftData

/// 设置面板：4 项设置 + 7 天统计柱状图
struct SettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.system(size: 20, weight: .semibold))
                .padding(.bottom, 4)

            // 设置组
            VStack(alignment: .leading, spacing: 16) {
                stepperRow(value: $appState.dailyGoal)
                toggleRow(title: "自动衔接下一阶段", isOn: $appState.autoContinue)
                toggleRow(title: "阶段结束发声", isOn: $appState.soundEnabled)
                toggleRow(title: "发送系统通知", isOn: $appState.notificationsEnabled)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // 7 天统计
            VStack(alignment: .leading, spacing: 8) {
                Text("最近 7 天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                WeeklyChartView(data: weeklyData, dailyGoal: appState.dailyGoal)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(24)
        .frame(width: 460, height: 540)
        .glassEffect(.regular, in: .rect)
        .onAppear {
            appState.refreshTodayCompleted(context: modelContext)
        }
    }

    private func stepperRow(value: Binding<Int>) -> some View {
        HStack {
            Text("每日目标番茄数")
                .font(.system(size: 13))
            Spacer()
            Stepper(value: value, in: 1...20) {
                Text("\(value.wrappedValue) 个")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    // MARK: 7 天数据

    private var weeklyData: [WeeklyChartView.DayData] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans")
        formatter.dateFormat = "M/d"

        // 拉取最近 7 天的 FocusSession
        let sessions: [FocusSession] = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
        let map: [Date: Int] = Dictionary(sessions.map { ($0.date, $0.completedCount) }, uniquingKeysWith: { a, _ in a })

        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let isToday = offset == 0
            let count = map[day] ?? 0
            return WeeklyChartView.DayData(
                date: day,
                label: formatter.string(from: day),
                count: count,
                isToday: isToday
            )
        }
    }
}
