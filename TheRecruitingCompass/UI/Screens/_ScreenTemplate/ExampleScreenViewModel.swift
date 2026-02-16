import Foundation
import Observation

/// Template ViewModel - copy this and customize
/// Usage: Rename ExampleScreen to your feature (e.g., SchoolsList, CoachDetail)
@Observable
@MainActor
final class ExampleScreenViewModel {
    // MARK: - Published Properties (UI State)
    var data: [String] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private Properties
    private let exampleService = ExampleService()

    // MARK: - Public Methods

    /// Fetch data from service
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            data = try await exampleService.fetchData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
