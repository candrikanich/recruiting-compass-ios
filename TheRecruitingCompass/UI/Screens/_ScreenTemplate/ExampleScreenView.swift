import SwiftUI

/// Template View - copy this and customize
struct ExampleScreenView: View {
    @State private var viewModel = ExampleScreenViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task {
                            await viewModel.loadData()
                        }
                    }
                }
                .padding()
            } else if viewModel.data.isEmpty {
                Text("No data")
                    .foregroundColor(.gray)
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
