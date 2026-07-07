import Foundation
import Observation

enum PlanImportSessionState: String, Codable, CaseIterable {
    case waiting
    case received
    case committed
    case cancelled
    case expired
}

struct PlanImportSessionDocument: Codable {
    var id: UUID
    var state: PlanImportSessionState
    var createdAt: Date
    var expiresAt: Date
    var committedAt: Date?
    var stagedPlan: PlanImportPayload?
    var lastError: String?

    var isExpired: Bool {
        Date() >= expiresAt
    }

    var summary: PlanImportSummary? {
        stagedPlan?.summaryInfo
    }
}

@Observable
final class PlanImportSessionController {
    let url: URL
    let helperPath: String
    let overwritePlanID: UUID?

    private(set) var document: PlanImportSessionDocument
    private(set) var errorMessage: String?

    init(url: URL, helperPath: String, overwritePlanID: UUID?, document: PlanImportSessionDocument) {
        self.url = url
        self.helperPath = helperPath
        self.overwritePlanID = overwritePlanID
        self.document = document
    }

    var configurationSnippet: String {
        """
        {
          "mcpServers": {
            "tomato-clock-import": {
              "command": "\(helperPath)",
              "args": ["--session", "\(url.path)"]
            }
          }
        }
        """
    }

    func refresh() {
        do {
            document = try PlanImportSessionStore.load(from: url)
            errorMessage = nil
            if document.state == .waiting, document.isExpired {
                try PlanImportSessionStore.updateState(.expired, at: url)
                document = try PlanImportSessionStore.load(from: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        do {
            try PlanImportSessionStore.updateState(.cancelled, at: url)
            document = try PlanImportSessionStore.load(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markCommitted() {
        do {
            var updated = try PlanImportSessionStore.load(from: url)
            updated.state = .committed
            updated.committedAt = Date()
            try PlanImportSessionStore.save(updated, to: url)
            document = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum PlanImportSessionStore {
    static let timeout: TimeInterval = 30 * 60

    static func create(overwritePlanID: UUID?, root: URL? = nil) throws -> PlanImportSessionController {
        let directory = root ?? FileManager.default.temporaryDirectory.appendingPathComponent(
            "TomatoClockImports",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let now = Date()
        let document = PlanImportSessionDocument(
            id: UUID(),
            state: .waiting,
            createdAt: now,
            expiresAt: now.addingTimeInterval(timeout),
            committedAt: nil,
            stagedPlan: nil,
            lastError: nil
        )
        let url = directory.appendingPathComponent("\(document.id.uuidString).json")
        try save(document, to: url)

        return PlanImportSessionController(
            url: url,
            helperPath: helperPath(),
            overwritePlanID: overwritePlanID,
            document: document
        )
    }

    static func load(from url: URL) throws -> PlanImportSessionDocument {
        let data = try Data(contentsOf: url)
        return try decoder.decode(PlanImportSessionDocument.self, from: data)
    }

    static func save(_ document: PlanImportSessionDocument, to url: URL) throws {
        let data = try encoder.encode(document)
        try data.write(to: url, options: [.atomic])
    }

    static func updateState(_ state: PlanImportSessionState, at url: URL) throws {
        var document = try load(from: url)
        guard document.state == .waiting || document.state == .received else { return }
        document.state = state
        try save(document, to: url)
    }

    private static func helperPath() -> String {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("script/tomato-clock-mcp"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/TomatoClock/script/tomato-clock-mcp"),
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate.path
        }
        return "tomato-clock-mcp"
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
