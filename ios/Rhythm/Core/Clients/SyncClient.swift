import Foundation
import ComposableArchitecture

/// Errors surfaced by the sync client. `unauthorized` (HTTP 401) signals the
/// caller should refresh the access token and retry.
enum SyncError: Error, Equatable { case unauthorized }

/// A single record mutation to sync. Field names / date format match the Go
/// backend's `sync.Change` (see backend/internal/sync). `deletedAt` carries a
/// tombstone so deletes propagate.
struct SyncChange: Encodable {
    let table: String
    let id: String
    let data: any Encodable
    let updatedAt: Date
    let deletedAt: Date?

    init(table: String, id: String, data: any Encodable, updatedAt: Date, deletedAt: Date? = nil) {
        self.table = table
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case table, id, data
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(table, forKey: .table)
        try container.encode(id, forKey: .id)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encode(AnyEncodable(data), forKey: .data)
    }
}

@DependencyClient
struct SyncClient {
    // Push requires the access token (the /sync endpoints are authenticated).
    var pushChanges: @Sendable ([SyncChange], String) async throws -> Void = { _, _ in }
    var pull: @Sendable (String) async throws -> Void = { _ in } // access token
}

extension SyncClient: DependencyKey {
    // A single encoder/decoder pair configured to match the Go backend, which
    // (de)serializes time.Time as RFC3339 strings. The default JSONEncoder would
    // encode Date as a number and the server would reject it.
    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static let liveValue = SyncClient(
        pushChanges: { changes, token in
            let url = URL(string: "http://localhost:8080/sync/push")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try makeEncoder().encode(["changes": changes])

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 { throw SyncError.unauthorized }
            guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        },
        pull: { token in
            let since = UserDefaults.standard.string(forKey: "lastSyncTime") ?? "2000-01-01T00:00:00Z"
            var url = URL(string: "http://localhost:8080/sync/pull")!
            url.append(queryItems: [URLQueryItem(name: "since", value: since)])
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 { throw SyncError.unauthorized }
            guard http.statusCode == 200 else { throw URLError(.badServerResponse) }

            // Apply the pulled changes to local SwiftData (upsert + tombstone).
            _ = try? await DataStore.shared.applyPulledChanges(data)

            // Advance the cursor using the server-authoritative `cursor` field
            // (falls back to `server_time`). Using the server cursor — not the
            // wall clock — is what prevents missed changes under clock skew.
            if let json = try? JSONDecoder().decode(PullResponse.self, from: data) {
                let next = json.cursor ?? json.serverTime
                UserDefaults.standard.set(next, forKey: "lastSyncTime")
            }
        }
    )
}

private struct PullResponse: Decodable {
    let cursor: String?
    let serverTime: String
    enum CodingKeys: String, CodingKey {
        case cursor
        case serverTime = "server_time"
    }
}

extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}
