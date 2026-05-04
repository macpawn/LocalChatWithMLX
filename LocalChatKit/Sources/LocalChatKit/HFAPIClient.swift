import Foundation

// MARK: - Models

struct HFFileMeta {
    let relativePath: String
    let sha256: String
    let size: Int64
}

struct HFRepoMeta {
    let commitHash: String
    let files: [HFFileMeta]

    var totalBytes: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}

// MARK: - Error

enum HFError: Error {
    case badResponse
    case invalidURL
}

protocol HFRepoMetadataProviding: Sendable {
    func fetchRepoMeta(modelID: String) async throws -> HFRepoMeta
}

struct LiveHFRepoMetadataProvider: HFRepoMetadataProviding {
    func fetchRepoMeta(modelID: String) async throws -> HFRepoMeta {
        try await fetchHFRepoMeta(modelID: modelID)
    }
}

// MARK: - API Response

private struct HFModelResponse: Decodable {
    struct Sibling: Decodable {
        let rfilename: String
    }
    let sha: String
    let siblings: [Sibling]
}

// MARK: - Fetch

func fetchHFRepoMeta(
    modelID: String,
    allowedExtensions: Set<String> = ["safetensors", "json", "jinja"],
    maxConcurrentRequests: Int = 5
) async throws -> HFRepoMeta {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "huggingface.co"
    components.path = "/api/models/\(modelID)"
    guard let apiURL = components.url else { throw HFError.invalidURL }
    let (data, _) = try await URLSession.shared.data(from: apiURL)
    let model = try JSONDecoder().decode(HFModelResponse.self, from: data)

    let filteredFiles = model.siblings.filter {
        let ext = URL(fileURLWithPath: $0.rfilename).pathExtension
        return allowedExtensions.contains(ext)
    }

    let semaphore = AsyncSemaphore(limit: maxConcurrentRequests)

    let files: [HFFileMeta] = try await withThrowingTaskGroup(of: HFFileMeta?.self) { group in
        for file in filteredFiles {
            group.addTask {
                try await semaphore.acquire()
                do {
                    let result = try await fetchSingleFileMeta(
                        modelID: modelID,
                        revision: model.sha,
                        filename: file.rfilename
                    )
                    await semaphore.release()
                    return result
                } catch {
                    await semaphore.release()
                    return nil
                }
            }
        }
        var result: [HFFileMeta] = []
        for try await file in group {
            if let file { result.append(file) }
        }
        return result
    }

    return HFRepoMeta(commitHash: model.sha, files: files)
}

// MARK: - Single File HEAD

private func fetchSingleFileMeta(
    modelID: String,
    revision: String,
    filename: String
) async throws -> HFFileMeta {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "huggingface.co"
    components.path = "/\(modelID)/resolve/\(revision)/\(filename)"
    guard let url = components.url else { throw HFError.invalidURL }
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw HFError.badResponse }

    let size: Int64 = {
        if let value = http.value(forHTTPHeaderField: "Content-Length"),
           let intVal = Int64(value) { return intVal }
        return 0
    }()

    let sha256: String = {
        // X-Linked-Etag contains the actual SHA-256 for LFS files.
        // Regular ETag is an opaque revision string for non-LFS files and must not be used for integrity checks.
        guard let etag = http.value(forHTTPHeaderField: "X-Linked-Etag") else { return "" }
        return etag
            .replacingOccurrences(of: "W/", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }()

    return HFFileMeta(relativePath: filename, sha256: sha256, size: size)
}
