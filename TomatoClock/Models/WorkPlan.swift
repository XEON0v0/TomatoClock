import Foundation
import SwiftData

enum PlanItemPriority: String, CaseIterable, Codable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .low: "低"
        case .normal: "普通"
        case .high: "高"
        }
    }
}

@Model
final class WorkPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String?
    var sourceKind: String?
    var sourceExternalID: String?
    var sourceURL: URL?
    var currentItemID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var lastImportedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PlanSection.plan)
    var sections: [PlanSection]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        sourceKind: String? = nil,
        sourceExternalID: String? = nil,
        sourceURL: URL? = nil,
        currentItemID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastImportedAt: Date? = nil,
        sections: [PlanSection] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.sourceKind = sourceKind
        self.sourceExternalID = sourceExternalID
        self.sourceURL = sourceURL
        self.currentItemID = currentItemID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastImportedAt = lastImportedAt
        self.sections = sections
        normalizeCurrentItem()
    }
}

@Model
final class PlanSection {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String?
    var externalID: String?
    var sortOrder: Int
    var plan: WorkPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlanItem.section)
    var items: [PlanItem]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        externalID: String? = nil,
        sortOrder: Int = 0,
        items: [PlanItem] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.externalID = externalID
        self.sortOrder = sortOrder
        self.items = items
    }
}

@Model
final class PlanItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var externalID: String?
    var url: URL?
    var estimatedMinutes: Int?
    var priorityRawValue: String
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var section: PlanSection?

    var priority: PlanItemPriority {
        get { PlanItemPriority(rawValue: priorityRawValue) ?? .normal }
        set { priorityRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        externalID: String? = nil,
        url: URL? = nil,
        estimatedMinutes: Int? = nil,
        priority: PlanItemPriority = .normal,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.externalID = externalID
        self.url = url
        self.estimatedMinutes = estimatedMinutes
        self.priorityRawValue = priority.rawValue
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sortOrder = sortOrder
    }

    func setCompleted(_ completed: Bool, at date: Date = Date()) {
        isCompleted = completed
        completedAt = completed ? date : nil
    }
}

extension WorkPlan {
    var sortedSections: [PlanSection] {
        sections.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder { return lhs.title < rhs.title }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var sortedItems: [PlanItem] {
        sortedSections.flatMap(\.sortedItems)
    }

    var totalItemCount: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }

    var completedItemCount: Int {
        sections.reduce(0) { partial, section in
            partial + section.items.filter(\.isCompleted).count
        }
    }

    var currentItem: PlanItem? {
        guard let currentItemID else { return nil }
        return sortedItems.first { $0.id == currentItemID }
    }

    var firstIncompleteItem: PlanItem? {
        sortedItems.first { !$0.isCompleted }
    }

    func normalizeCurrentItem() {
        if let currentItemID, sortedItems.contains(where: { $0.id == currentItemID }) {
            return
        }
        self.currentItemID = firstIncompleteItem?.id ?? sortedItems.first?.id
    }

    func setCurrentItem(_ item: PlanItem?) {
        currentItemID = item?.id
        touch()
    }

    func updateAfterItemCompletion(_ item: PlanItem) {
        if item.id == currentItemID, item.isCompleted {
            currentItemID = firstIncompleteItem?.id
        } else {
            normalizeCurrentItem()
        }
        touch()
    }

    func touch(date: Date = Date()) {
        updatedAt = date
    }
}

extension PlanSection {
    var sortedItems: [PlanItem] {
        items.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder { return lhs.title < rhs.title }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var totalItemCount: Int { items.count }

    var completedItemCount: Int {
        items.filter(\.isCompleted).count
    }
}
