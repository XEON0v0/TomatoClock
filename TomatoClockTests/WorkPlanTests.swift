import Testing
@testable import TomatoClock

@Suite("WorkPlan 计划语义")
struct WorkPlanTests {

    @Test("导入计划使用建议 currentItemExternalID")
    func importUsesSuggestedCurrentItem() throws {
        let plan = WorkPlan(importPayload: payload(current: "b"))

        #expect(plan.totalItemCount == 3)
        #expect(plan.completedItemCount == 0)
        #expect(plan.currentItem?.externalID == "b")
    }

    @Test("当前任务完成后推进到下一项未完成任务")
    func completingCurrentItemAdvances() throws {
        let plan = WorkPlan(importPayload: payload(current: "a"))
        let current = try #require(plan.currentItem)

        current.setCompleted(true)
        plan.updateAfterItemCompletion(current)

        #expect(plan.currentItem?.externalID == "b")
        #expect(plan.completedItemCount == 1)
    }

    @Test("覆盖导入保留 externalID 匹配项的完成状态")
    func overwritePreservesCompletionByExternalID() throws {
        let plan = WorkPlan(importPayload: payload(current: "a"))
        let done = try #require(plan.sortedItems.first { $0.externalID == "b" })
        done.setCompleted(true)

        plan.overwrite(with: payload(title: "Updated", current: nil))

        let preserved = try #require(plan.sortedItems.first { $0.externalID == "b" })
        #expect(plan.title == "Updated")
        #expect(preserved.isCompleted)
    }

    @Test("覆盖导入可用分区标题和任务标题回退匹配")
    func overwriteFallsBackToSectionAndTitle() throws {
        let plan = WorkPlan(importPayload: payload(current: nil, includeExternalIDs: false))
        let done = try #require(plan.sortedItems.first { $0.title == "Read brief" })
        done.setCompleted(true)

        plan.overwrite(with: payload(current: nil, includeExternalIDs: false))

        let preserved = try #require(plan.sortedItems.first { $0.title == "Read brief" })
        #expect(preserved.isCompleted)
    }

    private func payload(
        title: String = "Today",
        current: String?,
        includeExternalIDs: Bool = true
    ) -> PlanImportPayload {
        PlanImportPayload(
            schemaVersion: 1,
            title: title,
            summary: "Focus plan",
            source: .init(kind: "agent", externalID: "plan-1", url: nil),
            currentItemExternalID: current,
            sections: [
                .init(
                    title: "Planning",
                    summary: nil,
                    externalID: includeExternalIDs ? "s1" : nil,
                    items: [
                        .init(title: "Open notes", notes: nil, externalID: includeExternalIDs ? "a" : nil, url: nil, estimatedMinutes: 10, priority: .normal),
                        .init(title: "Read brief", notes: nil, externalID: includeExternalIDs ? "b" : nil, url: nil, estimatedMinutes: 20, priority: .high),
                    ]
                ),
                .init(
                    title: "Build",
                    summary: nil,
                    externalID: includeExternalIDs ? "s2" : nil,
                    items: [
                        .init(title: "Implement slice", notes: nil, externalID: includeExternalIDs ? "c" : nil, url: nil, estimatedMinutes: 25, priority: .normal)
                    ]
                ),
            ]
        )
    }
}
