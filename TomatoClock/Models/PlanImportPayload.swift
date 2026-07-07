import Foundation

struct PlanImportPayload: Codable, Equatable {
    var schemaVersion: Int
    var title: String
    var summary: String?
    var source: Source?
    var currentItemExternalID: String?
    var sections: [Section]

    struct Source: Codable, Equatable {
        var kind: String?
        var externalID: String?
        var url: String?
    }

    struct Section: Codable, Equatable {
        var title: String
        var summary: String?
        var externalID: String?
        var items: [Item]
    }

    struct Item: Codable, Equatable {
        var title: String
        var notes: String?
        var externalID: String?
        var url: String?
        var estimatedMinutes: Int?
        var priority: PlanItemPriority?
    }
}

struct PlanImportSummary: Codable, Equatable {
    var title: String
    var sectionCount: Int
    var itemCount: Int
    var previewItems: [String]
}

enum PlanImportValidationError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case emptyTitle
    case emptySections
    case emptySectionTitle(index: Int)
    case emptyItems(section: Int)
    case emptyItemTitle(section: Int, item: Int)
    case invalidEstimatedMinutes(section: Int, item: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "schemaVersion must be 1, received \(version)."
        case .emptyTitle:
            "Plan title is required."
        case .emptySections:
            "At least one section is required."
        case .emptySectionTitle(let index):
            "Section \(index + 1) title is required."
        case .emptyItems(let section):
            "Section \(section + 1) must contain at least one item."
        case .emptyItemTitle(let section, let item):
            "Item \(item + 1) in section \(section + 1) title is required."
        case .invalidEstimatedMinutes(let section, let item):
            "Item \(item + 1) in section \(section + 1) estimatedMinutes must be positive."
        }
    }
}

extension PlanImportPayload {
    func validated() throws -> PlanImportPayload {
        guard schemaVersion == 1 else {
            throw PlanImportValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanImportValidationError.emptyTitle
        }
        guard !sections.isEmpty else {
            throw PlanImportValidationError.emptySections
        }

        for (sectionIndex, section) in sections.enumerated() {
            guard !section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PlanImportValidationError.emptySectionTitle(index: sectionIndex)
            }
            guard !section.items.isEmpty else {
                throw PlanImportValidationError.emptyItems(section: sectionIndex)
            }
            for (itemIndex, item) in section.items.enumerated() {
                guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw PlanImportValidationError.emptyItemTitle(section: sectionIndex, item: itemIndex)
                }
                if let estimatedMinutes = item.estimatedMinutes, estimatedMinutes <= 0 {
                    throw PlanImportValidationError.invalidEstimatedMinutes(section: sectionIndex, item: itemIndex)
                }
            }
        }

        return self
    }

    var summaryInfo: PlanImportSummary {
        let previewItems = sections
            .flatMap(\.items)
            .prefix(5)
            .map(\.title)
        return PlanImportSummary(
            title: title,
            sectionCount: sections.count,
            itemCount: sections.reduce(0) { $0 + $1.items.count },
            previewItems: Array(previewItems)
        )
    }
}

extension WorkPlan {
    convenience init(importPayload payload: PlanImportPayload, importedAt: Date = Date()) {
        let sections = payload.sections.enumerated().map { sectionIndex, importedSection in
            PlanSection(
                title: importedSection.title,
                summary: importedSection.summary,
                externalID: importedSection.externalID,
                sortOrder: sectionIndex,
                items: importedSection.items.enumerated().map { itemIndex, importedItem in
                    PlanItem(
                        title: importedItem.title,
                        notes: importedItem.notes,
                        externalID: importedItem.externalID,
                        url: importedItem.url.flatMap(URL.init(string:)),
                        estimatedMinutes: importedItem.estimatedMinutes,
                        priority: importedItem.priority ?? .normal,
                        sortOrder: itemIndex
                    )
                }
            )
        }

        self.init(
            title: payload.title,
            summary: payload.summary,
            sourceKind: payload.source?.kind,
            sourceExternalID: payload.source?.externalID,
            sourceURL: payload.source?.url.flatMap(URL.init(string:)),
            createdAt: importedAt,
            updatedAt: importedAt,
            lastImportedAt: importedAt,
            sections: sections
        )
        applySuggestedCurrentItem(externalID: payload.currentItemExternalID)
    }

    func overwrite(with payload: PlanImportPayload, importedAt: Date = Date()) {
        let previousCurrentItem = currentItem
        let previousCurrentSectionTitle = previousCurrentItem.flatMap(sectionTitle(containing:))
        let previousItems = sortedItems
        var previousFallbackMatches: [String: PlanItem] = [:]
        for section in sortedSections {
            for item in section.sortedItems {
                let key = Self.fallbackKey(sectionTitle: section.title, itemTitle: item.title)
                previousFallbackMatches[key] = previousFallbackMatches[key] ?? item
            }
        }
        let newSections = payload.sections.enumerated().map { sectionIndex, importedSection in
            PlanSection(
                title: importedSection.title,
                summary: importedSection.summary,
                externalID: importedSection.externalID,
                sortOrder: sectionIndex,
                items: importedSection.items.enumerated().map { itemIndex, importedItem in
                    let completionMatch = Self.match(
                        importedItem: importedItem,
                        importedSectionTitle: importedSection.title,
                        previousItems: previousItems
                    )
                    return PlanItem(
                        title: importedItem.title,
                        notes: importedItem.notes,
                        externalID: importedItem.externalID,
                        url: importedItem.url.flatMap(URL.init(string:)),
                        estimatedMinutes: importedItem.estimatedMinutes,
                        priority: importedItem.priority ?? .normal,
                        isCompleted: (completionMatch ?? previousFallbackMatches[Self.fallbackKey(sectionTitle: importedSection.title, itemTitle: importedItem.title)])?.isCompleted ?? false,
                        completedAt: (completionMatch ?? previousFallbackMatches[Self.fallbackKey(sectionTitle: importedSection.title, itemTitle: importedItem.title)])?.completedAt,
                        sortOrder: itemIndex
                    )
                }
            )
        }

        title = payload.title
        summary = payload.summary
        sourceKind = payload.source?.kind
        sourceExternalID = payload.source?.externalID
        sourceURL = payload.source?.url.flatMap(URL.init(string:))
        sections = newSections
        updatedAt = importedAt
        lastImportedAt = importedAt

        if let suggested = payload.currentItemExternalID,
           let importedCurrent = sortedItems.first(where: { $0.externalID == suggested }) {
            currentItemID = importedCurrent.id
        } else if let previousCurrentItem,
                  let preservedCurrent = matchCurrentItem(
                    title: previousCurrentItem.title,
                    externalID: previousCurrentItem.externalID,
                    sectionTitle: previousCurrentSectionTitle
                  ) {
            currentItemID = preservedCurrent.id
        } else {
            currentItemID = firstIncompleteItem?.id
        }
    }

    private func applySuggestedCurrentItem(externalID: String?) {
        if let externalID,
           let item = sortedItems.first(where: { $0.externalID == externalID }) {
            currentItemID = item.id
        } else {
            normalizeCurrentItem()
        }
    }

    private static func match(
        importedItem: PlanImportPayload.Item,
        importedSectionTitle: String,
        previousItems: [PlanItem]
    ) -> PlanItem? {
        match(
            importedItemTitle: importedItem.title,
            importedExternalID: importedItem.externalID,
            importedSectionTitle: importedSectionTitle,
            newItems: previousItems
        )
    }

    private static func match(
        importedItemTitle: String,
        importedExternalID: String?,
        importedSectionTitle: String?,
        newItems: [PlanItem]
    ) -> PlanItem? {
        if let importedExternalID,
           let match = newItems.first(where: { $0.externalID == importedExternalID }) {
            return match
        }
        return newItems.first {
            $0.title == importedItemTitle && $0.section?.title == importedSectionTitle
        }
    }

    private func sectionTitle(containing item: PlanItem) -> String? {
        sortedSections.first { section in
            section.sortedItems.contains { $0.id == item.id }
        }?.title
    }

    private func matchCurrentItem(title: String, externalID: String?, sectionTitle: String?) -> PlanItem? {
        if let externalID,
           let match = sortedItems.first(where: { $0.externalID == externalID }) {
            return match
        }
        guard let sectionTitle else { return nil }
        return sortedSections
            .first { $0.title == sectionTitle }?
            .sortedItems
            .first { $0.title == title }
    }

    private static func fallbackKey(sectionTitle: String, itemTitle: String) -> String {
        "\(sectionTitle)\u{1F}\(itemTitle)"
    }
}
