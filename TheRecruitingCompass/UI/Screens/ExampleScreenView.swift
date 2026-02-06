import SwiftUI

struct ExampleScreenView: View {
    @StateObject var viewModel = ExampleScreenViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
            } else {
                List(viewModel.data, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .navigationTitle("Example")
        .task {
            await viewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        ExampleScreenView()
    }
}
