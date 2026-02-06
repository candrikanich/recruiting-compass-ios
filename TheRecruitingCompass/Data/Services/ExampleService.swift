import Foundation

/// Template Service - copy and customize for your data
/// Services handle all API calls and business logic
final class ExampleService {

    /// Fetch data from your API or local storage
    func fetchData() async throws -> [String] {
        // Replace with your actual API call
        // Example:
        // let url = URL(string: "https://api.example.com/data")!
        // let (data, _) = try await URLSession.shared.data(from: url)
        // let decoded = try JSONDecoder().decode([String].self, from: data)
        // return decoded

        return ["Item 1", "Item 2", "Item 3"]
    }
}
