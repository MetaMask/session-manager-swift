import Foundation

actor RefreshCoordinator {
    private var refreshTask: Task<RefreshResponse, Error>?

    func ensureRefresh(
        skipIfFresh: Bool,
        resolveFresh: @escaping () async throws -> RefreshResponse?,
        perform: @escaping () async throws -> RefreshResponse
    ) async throws -> RefreshResponse {
        if skipIfFresh, let cached = try await resolveFresh() {
            return cached
        }
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }
        let task = Task<RefreshResponse, Error> {
            if skipIfFresh, let cached = try await resolveFresh() {
                return cached
            }
            return try await perform()
        }
        refreshTask = task
        do {
            let result = try await task.value
            refreshTask = nil
            return result
        } catch {
            refreshTask = nil
            throw error
        }
    }
}
