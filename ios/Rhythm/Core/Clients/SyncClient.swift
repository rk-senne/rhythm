import Foundation
import ComposableArchitecture

struct SyncChange: Encodable {
    let table: String
    let id: String
    let data: any Encodable
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case table, id, data
        case updatedAt = "updated_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(table, forKey: .table)
        try container.encode(id, forKey: .id)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(AnyEncodable(data), forKey: .data)
    }
}

@DependencyClient
struct SyncClient {
    var pushChanges: @Sendable ([SyncChange]) async throws -> Void = { _ in }
    var pull: @Sendable (String) async throws -> Void = { _ in } // token
}

extension SyncClient: DependencyKey {
    static let liveValue = SyncClient(
        pushChanges: { changes in
            let url = URL(string: "http://localhost:8080/sync/push")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["changes": changes])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        },
        pull: { token in
            let since = UserDefaults.standard.string(forKey: "lastSyncTime") ?? "2000-01-01T00:00:00Z"
            var url = URL(string: "http://localhost:8080/sync/pull")!
            url.append(queryItems: [URLQueryItem(name: "since", value: since)])
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            // Store server time for next pull
            if let json = try? JSONDecoder().decode(PullResponse.self, from: data) {
                UserDefaults.standard.set(json.serverTime, forKey: "lastSyncTime")
            }
        }
    )
}

private struct PullResponse: Decodable {
    let serverTime: String
    enum CodingKeys: String, CodingKey { case serverTime = "server_time" }
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
