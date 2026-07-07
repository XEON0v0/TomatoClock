import SwiftUI
import SwiftData

struct PlanEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkPlan
    @State private var title: String
    @State private var summary: String

    init(plan: WorkPlan) {
        self.plan = plan
        _title = State(initialValue: plan.title)
        _summary = State(initialValue: plan.summary ?? "")
    }

    var body: some View {
        Form {
            TextField("标题", text: $title)
            TextField("摘要", text: $summary, axis: .vertical)
        }
        .padding(24)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    plan.title = title.trimmedFallback("未命名计划")
                    plan.summary = summary.nilIfBlank
                    plan.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct SectionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let section: PlanSection
    @State private var title: String
    @State private var summary: String

    init(section: PlanSection) {
        self.section = section
        _title = State(initialValue: section.title)
        _summary = State(initialValue: section.summary ?? "")
    }

    var body: some View {
        Form {
            TextField("标题", text: $title)
            TextField("摘要", text: $summary, axis: .vertical)
        }
        .padding(24)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    section.title = title.trimmedFallback("未命名分区")
                    section.summary = summary.nilIfBlank
                    section.plan?.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct SectionCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkPlan
    @State private var title = ""
    @State private var summary = ""

    var body: some View {
        Form {
            TextField("标题", text: $title)
            TextField("摘要", text: $summary, axis: .vertical)
        }
        .padding(24)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    let section = PlanSection(
                        title: title.trimmedFallback("新分区"),
                        summary: summary.nilIfBlank,
                        sortOrder: plan.sections.count
                    )
                    plan.sections.append(section)
                    plan.normalizeCurrentItem()
                    plan.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct ItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: PlanItem
    @State private var title: String
    @State private var notes: String
    @State private var url: String
    @State private var estimatedMinutes: Int?
    @State private var priority: PlanItemPriority

    init(item: PlanItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes ?? "")
        _url = State(initialValue: item.url?.absoluteString ?? "")
        _estimatedMinutes = State(initialValue: item.estimatedMinutes)
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        Form {
            TextField("标题", text: $title)
            TextField("备注", text: $notes, axis: .vertical)
            TextField("链接", text: $url)
            Stepper(value: estimatedMinutesBinding, in: 1...480) {
                Text("预计 \(estimatedMinutes ?? 25) 分钟")
            }
            Picker("优先级", selection: $priority) {
                ForEach(PlanItemPriority.allCases) { priority in
                    Text(priority.localizedName).tag(priority)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    item.title = title.trimmedFallback("未命名任务")
                    item.notes = notes.nilIfBlank
                    item.url = url.nilIfBlank.flatMap(URL.init(string:))
                    item.estimatedMinutes = estimatedMinutes
                    item.priority = priority
                    item.section?.plan?.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private var estimatedMinutesBinding: Binding<Int> {
        Binding(
            get: { estimatedMinutes ?? 25 },
            set: { estimatedMinutes = $0 }
        )
    }
}

struct ItemCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let section: PlanSection
    @State private var title = ""
    @State private var notes = ""
    @State private var url = ""
    @State private var estimatedMinutes: Int? = 25
    @State private var priority: PlanItemPriority = .normal

    var body: some View {
        Form {
            TextField("标题", text: $title)
            TextField("备注", text: $notes, axis: .vertical)
            TextField("链接", text: $url)
            Stepper(value: estimatedMinutesBinding, in: 1...480) {
                Text("预计 \(estimatedMinutes ?? 25) 分钟")
            }
            Picker("优先级", selection: $priority) {
                ForEach(PlanItemPriority.allCases) { priority in
                    Text(priority.localizedName).tag(priority)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    let item = PlanItem(
                        title: title.trimmedFallback("新任务"),
                        notes: notes.nilIfBlank,
                        url: url.nilIfBlank.flatMap(URL.init(string:)),
                        estimatedMinutes: estimatedMinutes,
                        priority: priority,
                        sortOrder: section.items.count
                    )
                    section.items.append(item)
                    section.plan?.normalizeCurrentItem()
                    section.plan?.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private var estimatedMinutesBinding: Binding<Int> {
        Binding(
            get: { estimatedMinutes ?? 25 },
            set: { estimatedMinutes = $0 }
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func trimmedFallback(_ fallback: String) -> String {
        nilIfBlank ?? fallback
    }
}
