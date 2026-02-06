import Foundation
import Combine

/// Template ViewModel - copy this and customize
/// Usage: Rename ExampleScreen to your feature (e.g., SchoolsList, CoachDetail)
@MainActor
final class ExampleScreenViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    @Published var data: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
