import SwiftUI

struct ContentView: View {
    @ObservedObject private var viewModel = TaskViewModel()
    @State private var showingNewTaskSheet = false
    @State private var selectedTask: Tasks?
    @State private var showingRecommendations = false
    @State private var refresh = false
    
    var body: some View {
        NavigationStack {
            TaskListView(
                viewModel: viewModel,
                selectedTask: $selectedTask,
                showingNewTaskSheet: $showingNewTaskSheet
            )
            .id(refresh)
            .navigationTitle("Ace Your Day")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack{
                        RecommendationButton(showingRecommendations: $showingRecommendations)
                        AddTaskButton(showingSheet: $showingNewTaskSheet)
                    }
                    
                }
            }
            .sheet(isPresented: $showingNewTaskSheet) {
                FormView(viewModel: viewModel)
                
            }
            .sheet(item: $selectedTask) { task in
                FormView(viewModel: viewModel, taskToEdit: task)
            }
            .sheet(isPresented: $showingRecommendations) {
                RecommendationsView(viewModel: viewModel)
                .onDisappear {
                        Task {
                            print(viewModel.tasks)
                            refresh.toggle()
                        }
                    }
            }
        }
    }
}

struct AddTaskButton: View {
    @Binding var showingSheet: Bool
    @ObservedObject private var viewModel = TaskViewModel()
    
    var body: some View {
        Button {
            Task {
               do {
                   try await viewModel.getRecommendations()
               } catch {
                   print("Error: \(error.localizedDescription)")
               }
           }
            showingSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
}

struct RecommendationButton: View {
    @Binding var showingRecommendations: Bool
    @ObservedObject private var viewModel = TaskViewModel()
    
    var body: some View {
        Button {
            Task {
                do {
                    showingRecommendations = true
                    try await viewModel.getRecommendations()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        } label: {
            Image(systemName: "lightbulb")
        }
    }
}



struct TaskListView: View {
    @ObservedObject var viewModel: TaskViewModel
    @Binding var selectedTask: Tasks?
    @Binding var showingNewTaskSheet: Bool
    
    var body: some View {
        List {
            ForEach(viewModel.groupedTasks, id: \.0) { (workDate, tasks) in
                TaskSection(
                    workDate: workDate,
                    tasks: tasks,
                    viewModel: viewModel,
                    selectedTask: $selectedTask
                )
            }
        }
    }
}

struct TaskSection: View {
    let workDate: Date
    let tasks: [Tasks]
    @ObservedObject var viewModel: TaskViewModel
    @Binding var selectedTask: Tasks?
    
    var body: some View {
        Section(
            header: Text(formatDate(workDate))
                .font(.headline)
        ) {
            ForEach(tasks) {
                task in TaskRow(task: task, onToggleCompletion: {
                        viewModel.toggleTaskCompletion(task)
                    }, onRowTap: {
                        selectedTask = task
                    })
                }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter.string(from: date)
    }
}
    
   

struct TaskRow: View {
    let task: Tasks
    var onToggleCompletion: () -> Void
    var onRowTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                
                if let description = task.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("\(task.timeToFinish, specifier: "%.1f") hours", systemImage: "clock")
                    Spacer()
                    Text(task.importance.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(importanceColor(task.importance))
                        .cornerRadius(4)
                }
                .font(.caption)
            }
            .onTapGesture {
                onRowTap()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func importanceColor(_ importance: ImportanceLevel) -> Color {
        switch importance {
        case .low: return .green.opacity(0.2)
        case .medium: return .yellow.opacity(0.2)
        case .high: return .red.opacity(0.2)
        }
    }
}
