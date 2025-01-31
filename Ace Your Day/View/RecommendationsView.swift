import SwiftUI

struct RecommendationsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel
    @State private var isRefreshing = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private var hasInsufficientTasks: Bool {
        viewModel.tasks.count <= 1
    }
    
    private var alertDetails: (title: String, message: String) {
        if viewModel.tasks.isEmpty {
            return ("No Tasks Available", "Please add some tasks before requesting recommendations.")
        } else if viewModel.tasks.count == 1 {
            return ("Insufficient Tasks", "Add more tasks to get meaningful recommendations. AI needs to analyze multiple tasks to provide valuable insights.")
        }
        return ("", "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Recommendations")) {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Analyzing tasks...")
                            Spacer()
                        }
                        .padding()
                    } else if let recommendations = viewModel.recommendations {
                        Text(recommendations)
                            .font(.body)
                            .padding(.vertical, 8)
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    } else {
                        Text("No recommendations available yet")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button(action: {
                        if hasInsufficientTasks {
                            let details = alertDetails
                            alertTitle = details.title
                            alertMessage = details.message
                            showingAlert = true
                        } else {
                            refreshRecommendations()
                        }
                    }) {
                        HStack {
                            Text("Get Recommendations")
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                Section{
                    Button(action:{
                        acceptRecommendations()
                    }){
                        HStack{
                            Text("Accept Recommendation")
                        }
                    }
                }
            }
            .navigationTitle("Task Insights")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if hasInsufficientTasks {
                    let details = alertDetails
                    alertTitle = details.title
                    alertMessage = details.message
                    showingAlert = true
                }
            }
        }
    }
    
    private func refreshRecommendations() {
        Task {
            do {
                try await viewModel.getRecommendations()
            } catch {
                viewModel.handleError(error)
            }
        }
    }
    
    private func acceptRecommendations() {
        Task {
           await viewModel.acceptRecommendations()
            
            dismiss()
        }
    }
}
