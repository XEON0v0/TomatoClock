import SwiftUI
import SwiftData

struct PlanPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let plans: [WorkPlan]

    @State private var editingPlan: WorkPlan?
    @State private var editingSection: PlanSection?
    @State private var editingItem: PlanItem?
    @State private var showingAddSection = false
    @State private var addItemSection: PlanSection?

    private var activePlan: WorkPlan? {
        guard let activePlanID = appState.activePlanID else { return plans.first }
        return plans.first { $0.id == activePlanID } ?? plans.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plan = activePlan {
                planHeader(plan)
                Divider()
                planContent(plan)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editingPlan) { plan in
            PlanEditSheet(plan: plan)
        }
        .sheet(item: $editingSection) { section in
            SectionEditSheet(section: section)
        }
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item)
        }
        .sheet(isPresented: $showingAddSection) {
            if let plan = activePlan {
                SectionCreateSheet(plan: plan)
            }
        }
        .sheet(item: $addItemSection) { section in
            ItemCreateSheet(section: section)
        }
    }

    private func planHeader(_ plan: WorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 28, weight: .semibold))
                        .lineLimit(2)
                    if let summary = plan.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Menu {
                    if plans.count > 1 {
                        Picker("切换计划", selection: activePlanSelection) {
                            ForEach(plans) { plan in
                                Text(plan.title).tag(Optional(plan.id))
                            }
                        }
                        Divider()
                    }

                    Button("重命名与摘要") { editingPlan = plan }
                    Button("添加分区") { showingAddSection = true }
                    Button("导入新计划") { appState.startPlanImport(overwriting: nil) }
                    Button("用导入覆盖当前计划") { appState.startPlanImport(overwriting: plan) }
                    Divider()
                    Button("删除计划", role: .destructive) {
                        appState.delete(plan: plan, context: modelContext, remainingPlans: plans)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .frame(width: 30, height: 30)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            ProgressView(value: Double(plan.completedItemCount), total: Double(max(plan.totalItemCount, 1))) {
                Text("\(plan.completedItemCount) / \(plan.totalItemCount) 项完成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
    }

    private func planContent(_ plan: WorkPlan) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(plan.sortedSections) { section in
                    sectionView(section, plan: plan)
                }
            }
            .padding(28)
        }
    }

    private func sectionView(_ section: PlanSection, plan: WorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.headline)
                    Text("\(section.completedItemCount) / \(section.totalItemCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("添加任务") { addItemSection = section }
                    Button("编辑分区") { editingSection = section }
                    Button("上移") { moveSection(section, in: plan, delta: -1) }
                    Button("下移") { moveSection(section, in: plan, delta: 1) }
                    Divider()
                    Button("删除分区", role: .destructive) {
                        plan.sections.removeAll { $0.id == section.id }
                        modelContext.delete(section)
                        plan.normalizeCurrentItem()
                        plan.touch()
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 26, height: 24)
                }
                .buttonStyle(.plain)
            }

            if let summary = section.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(section.sortedItems) { item in
                    itemRow(item, section: section, plan: plan)
                }
            }
        }
    }

    private func itemRow(_ item: PlanItem, section: PlanSection, plan: WorkPlan) -> some View {
        let isCurrent = plan.currentItemID == item.id
        return HStack(alignment: .top, spacing: 10) {
            Button {
                appState.setCompletion(!item.isCompleted, for: item, in: plan, context: modelContext)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                    .strikethrough(item.isCompleted)
                HStack(spacing: 8) {
                    if isCurrent {
                        Label("当前", systemImage: "target")
                    }
                    if item.priority != .normal {
                        Label(item.priority.localizedName, systemImage: "flag.fill")
                    }
                    if let minutes = item.estimatedMinutes {
                        Label("\(minutes)分钟", systemImage: "clock")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("设为当前任务") {
                    plan.setCurrentItem(item)
                    try? modelContext.save()
                }
                Button("编辑任务") { editingItem = item }
                Button("上移") { moveItem(item, in: section, plan: plan, delta: -1) }
                Button("下移") { moveItem(item, in: section, plan: plan, delta: 1) }
                Divider()
                Button("删除任务", role: .destructive) {
                    section.items.removeAll { $0.id == item.id }
                    modelContext.delete(item)
                    plan.normalizeCurrentItem()
                    plan.touch()
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isCurrent ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("还没有计划")
                .font(.system(size: 28, weight: .semibold))
            HStack {
                Button("导入计划") {
                    appState.startPlanImport(overwriting: nil)
                }
                .buttonStyle(.borderedProminent)

                Button("创建空白计划") {
                    appState.createBlankPlan(context: modelContext)
                }
            }
            Spacer()
        }
        .padding(34)
    }

    private var activePlanSelection: Binding<UUID?> {
        Binding(
            get: { appState.activePlanID },
            set: { appState.activePlanID = $0 }
        )
    }

    private func moveSection(_ section: PlanSection, in plan: WorkPlan, delta: Int) {
        move(section, within: plan.sortedSections, delta: delta) { element, order in
            element.sortOrder = order
        }
        plan.touch()
        try? modelContext.save()
    }

    private func moveItem(_ item: PlanItem, in section: PlanSection, plan: WorkPlan, delta: Int) {
        move(item, within: section.sortedItems, delta: delta) { element, order in
            element.sortOrder = order
        }
        plan.touch()
        try? modelContext.save()
    }

    private func move<T: Identifiable>(_ value: T, within values: [T], delta: Int, apply: (T, Int) -> Void) where T.ID: Equatable {
        guard let index = values.firstIndex(where: { $0.id == value.id }) else { return }
        let target = index + delta
        guard values.indices.contains(target) else { return }
        var reordered = values
        reordered.swapAt(index, target)
        for (offset, element) in reordered.enumerated() {
            apply(element, offset)
        }
    }
}
