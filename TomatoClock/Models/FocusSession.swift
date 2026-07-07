import Foundation
import SwiftData

/// 每日专注完成数记录：一天一条
@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    /// 完成日期，归一化到当天 00:00
    var date: Date
    /// 当天累计完成的专注番茄数
    var completedCount: Int

    init(id: UUID = UUID(), date: Date, completedCount: Int = 0) {
        self.id = id
        self.date = date
        self.completedCount = completedCount
    }
}

// MARK: - Helpers

extension FocusSession {
    /// 将任意日期归一化到当天 00:00:00（使用本地时区）
    static func normalizeDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}

/// SwiftData 容器工厂
enum FocusSessionStore {
    static func makeContainer() -> ModelContainer {
        do {
            let schema = appSchema
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 回退到内存容器，避免崩溃阻断 UI
            let schema = appSchema
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }

    private static var appSchema: Schema {
        Schema([
            FocusSession.self,
            WorkPlan.self,
            PlanSection.self,
            PlanItem.self,
        ])
    }
}
