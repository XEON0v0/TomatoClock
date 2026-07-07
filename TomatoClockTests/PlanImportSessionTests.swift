import Foundation
import Testing
@testable import TomatoClock

@Suite("PlanImportSession 状态文件")
struct PlanImportSessionTests {

    @Test("创建 session 默认为 waiting 且 30 分钟后过期")
    func createSession() throws {
        let root = try temporaryDirectory()
        let session = try PlanImportSessionStore.create(overwritePlanID: nil, root: root)

        #expect(session.document.state == .waiting)
        #expect(session.document.stagedPlan == nil)
        #expect(session.document.expiresAt.timeIntervalSince(session.document.createdAt) == PlanImportSessionStore.timeout)
    }

    @Test("waiting session 可标记为 cancelled")
    func cancelSession() throws {
        let root = try temporaryDirectory()
        let session = try PlanImportSessionStore.create(overwritePlanID: nil, root: root)

        session.cancel()

        #expect(session.document.state == .cancelled)
        #expect(try PlanImportSessionStore.load(from: session.url).state == .cancelled)
    }

    @Test("received session 可标记为 committed")
    func commitSession() throws {
        let root = try temporaryDirectory()
        let session = try PlanImportSessionStore.create(overwritePlanID: nil, root: root)
        var document = session.document
        document.state = .received
        document.stagedPlan = PlanImportPayload(
            schemaVersion: 1,
            title: "Imported",
            summary: nil,
            source: nil,
            currentItemExternalID: nil,
            sections: [
                .init(
                    title: "One",
                    summary: nil,
                    externalID: nil,
                    items: [
                        .init(title: "Task", notes: nil, externalID: nil, url: nil, estimatedMinutes: nil, priority: nil)
                    ]
                )
            ]
        )
        try PlanImportSessionStore.save(document, to: session.url)

        session.markCommitted()

        #expect(session.document.state == .committed)
        #expect(session.document.committedAt != nil)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TomatoClockTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
