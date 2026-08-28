import OSLog

extension Logger {
    /// Executes a list query with standard debug/info/error logging.
    /// Catches `DecodingError` separately to log schema details that help diagnose mapping mismatches.
    func fetch<T: Decodable>(_ label: String, query: () async throws -> [T]) async throws -> [T] {
        debug("Fetching \(label)")
        do {
            let result = try await query()
            info("Fetched \(result.count) \(label)")
            return result
        } catch {
            logFetchFailure(label, error: error)
            throw error
        }
    }

    /// Same logging as `fetch`, for a single decoded row.
    func fetchOne<T: Decodable>(_ label: String, query: () async throws -> T) async throws -> T {
        debug("Fetching \(label)")
        do {
            let result = try await query()
            info("Fetched \(label)")
            return result
        } catch {
            logFetchFailure(label, error: error)
            throw error
        }
    }

    private func logFetchFailure(_ label: String, error: Error) {
        self.error("Failed to fetch \(label): \(error.localizedDescription)")
        if let decodingError = error as? DecodingError {
            self.error("Decoding error: \(String(describing: decodingError))")
        }
    }
}
