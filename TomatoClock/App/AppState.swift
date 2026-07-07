import Foundation
import SwiftData
import Observation

/// 全局应用状态：聚合计时引擎、设置、每日完成数
@Observable
final class AppState {

    /// 计时引擎
    let engine: TimerEngine

    /// 今日已完成专注番茄数（实时镜像 SwiftData，避免 UI 频繁查询）
    private(set) var todayCompleted: Int = 0

    /// 工作台当前选中的计划。
    var activePlanID: UUID? {
        didSet {
            if let activePlanID {
                UserDefaults.standard.set(activePlanID.uuidString, forKey: AppStorageKeys.activePlanID)
            } else {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.activePlanID)
            }
        }
    }

    var importSession: PlanImportSessionController?

    // MARK: Settings（通过 @AppStorage 持久化，这里镜像方便逻辑读取）

    var dailyGoal: Int {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: AppStorageKeys.dailyGoal) }
    }
    var autoContinue: Bool {
        didSet {
            UserDefaults.standard.set(autoContinue, forKey: AppStorageKeys.autoContinue)
            engine.autoContinue = autoContinue
        }
    }
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: AppStorageKeys.soundEnabled) }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: AppStorageKeys.notificationsEnabled) }
    }

    init(engine: TimerEngine = TimerEngine()) {
        self.engine = engine
        let defaults = UserDefaults.standard
        self.dailyGoal = defaults.object(forKey: AppStorageKeys.dailyGoal) as? Int ?? 8
        self.autoContinue = defaults.object(forKey: AppStorageKeys.autoContinue) as? Bool ?? true
        self.soundEnabled = defaults.object(forKey: AppStorageKeys.soundEnabled) as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: AppStorageKeys.notificationsEnabled) as? Bool ?? true
        self.activePlanID = (defaults.string(forKey: AppStorageKeys.activePlanID)).flatMap(UUID.init(uuidString:))
        engine.autoContinue = autoContinue
    }

    // MARK: Wiring

    /// 绑定引擎回调：阶段切换时发声音 / 通知；专注完成时写入计数
    func wireEngine(context: ModelContext) {
        engine.onFocusCompleted = { [weak self] _ in
            self?.incrementTodayCompleted(context: context)
        }
        engine.onPhaseTransition = { [weak self] from, to in
            self?.handlePhaseTransition(from: from, to: to)
        }
        refreshTodayCompleted(context: context)
    }

    // MARK: SwiftData

    func refreshTodayCompleted(context: ModelContext) {
        let dayStart = FocusSession.normalizeDay(Date())
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.date == dayStart }
        )
        if let session = try? context.fetch(descriptor).first {
            todayCompleted = session.completedCount
        } else {
            todayCompleted = 0
        }
    }

    func incrementTodayCompleted(context: ModelContext) {
        let dayStart = FocusSession.normalizeDay(Date())
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.date == dayStart }
        )
        if let session = try? context.fetch(descriptor).first {
            session.completedCount += 1
            todayCompleted = session.completedCount
        } else {
            let session = FocusSession(date: dayStart, completedCount: 1)
            context.insert(session)
            todayCompleted = 1
        }
        try? context.save()
    }

    // MARK: Phase transition side effects

    private func handlePhaseTransition(from: TimerPhase, to: TimerPhase) {
        if soundEnabled {
            SoundPlayer.shared.playBell()
        }
        if notificationsEnabled {
            NotificationManager.shared.sendPhaseNotification(newPhase: to, round: engine.currentRound)
        }
    }

    // MARK: Plans

    func ensureActivePlan(in plans: [WorkPlan]) {
        if let activePlanID, plans.contains(where: { $0.id == activePlanID }) {
            return
        }
        activePlanID = plans.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }

    func createBlankPlan(context: ModelContext) {
        let plan = WorkPlan(
            title: "新的计划",
            summary: nil,
            sections: [
                PlanSection(
                    title: "待办",
                    sortOrder: 0,
                    items: [
                        PlanItem(title: "写下第一项任务", sortOrder: 0)
                    ]
                )
            ]
        )
        context.insert(plan)
        activePlanID = plan.id
        try? context.save()
    }

    func delete(plan: WorkPlan, context: ModelContext, remainingPlans: [WorkPlan]) {
        context.delete(plan)
        if activePlanID == plan.id {
            activePlanID = remainingPlans.first(where: { $0.id != plan.id })?.id
        }
        try? context.save()
    }

    func setCompletion(_ completed: Bool, for item: PlanItem, in plan: WorkPlan, context: ModelContext) {
        item.setCompleted(completed)
        plan.updateAfterItemCompletion(item)
        try? context.save()
    }

    func startPlanImport(overwriting plan: WorkPlan?) {
        do {
            importSession = try PlanImportSessionStore.create(overwritePlanID: plan?.id)
        } catch {
            importSession = nil
        }
    }

    func commitImport(from session: PlanImportSessionController, context: ModelContext, plans: [WorkPlan]) throws {
        session.refresh()
        guard let payload = session.document.stagedPlan else { return }
        let validatedPayload = try payload.validated()

        if let overwritePlanID = session.overwritePlanID,
           let plan = plans.first(where: { $0.id == overwritePlanID }) {
            plan.overwrite(with: validatedPayload)
            activePlanID = plan.id
        } else {
            let plan = WorkPlan(importPayload: validatedPayload)
            context.insert(plan)
            activePlanID = plan.id
        }

        try context.save()
        session.markCommitted()
        importSession = nil
    }
}

enum AppStorageKeys {
    static let dailyGoal = "settings.dailyGoal"
    static let autoContinue = "settings.autoContinue"
    static let soundEnabled = "settings.soundEnabled"
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let activePlanID = "plans.activePlanID"
}
