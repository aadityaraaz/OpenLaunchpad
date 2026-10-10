import Foundation

struct ReleaseUpdates {
    struct Manifest: Decodable {
        let version: String
        let url: URL
        static func parse(_ data: Data) throws -> Manifest {
            let result = try JSONDecoder().decode(Self.self, from: data)
            guard !result.version.isEmpty, result.version.first?.isNumber == true,
                  result.url.scheme == "https", result.url.host != nil else { throw URLError(.badServerResponse) }
            return result
        }
    }
    static func fetch(_ url: URL) async throws -> Manifest {
        var request = URLRequest(url: url); request.timeoutInterval = 15; request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              http.url?.scheme == "https", data.count <= 1_048_576 else { throw URLError(.badServerResponse) }
        return try Manifest.parse(data)
    }
}
