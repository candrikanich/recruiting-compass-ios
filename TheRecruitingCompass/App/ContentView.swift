import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            LandingView()
        }
    }
}

struct StartHereView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("TheRecruitingCompass")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("iOS App")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Getting Started")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Look at web page")
                                    .font(.subheadline)
                                Text("Identify data & actions")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Copy _ScreenTemplate")
                                    .font(.subheadline)
                                Text("In UI/Screens/")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Follow HOW_TO_CREATE_SCREENS.md")
                                    .font(.subheadline)
                                Text("Rename & customize 3 files")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "4.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Build & test")
                                    .font(.subheadline)
                                Text("Cmd+R in Xcode")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()

                NavigationLink(destination: ExampleScreenView()) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("See Template Example")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(24)
            .navigationTitle("Start Here")
        }
    }
}

#Preview {
    ContentView()
}
