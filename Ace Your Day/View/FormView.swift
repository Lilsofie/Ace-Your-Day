import SwiftUI

struct FormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var workDate = Date()
    @State private var importance: ImportanceLevel = .medium
    @State private var timeToFinish: Double = 1.0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var taskToEdit: Tasks?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    Picker("Importance", selection: $importance) {
                        ForEach(ImportanceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue)
                        }
                    }
                    HStack {
                        Text("Time to Finish")
                        Spacer()
                        TextField("Hours", value: $timeToFinish, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if let taskToEdit = taskToEdit {
                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteTask(taskToEdit)
                            dismiss()
                        } label: {
                            Text("Delete")
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(taskToEdit == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Missing Information", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if let task = taskToEdit {
                    title = task.title
                    description = task.description ?? ""
                    dueDate = task.dueDate ?? Date()
                    importance = task.importance
                    timeToFinish = task.timeToFinish
                    workDate = task.workDate ?? dueDate
                }
            }
        }
    }
    
    private func saveTask() {
        guard !title.isEmpty else {
            alertMessage = "Please enter a title"
            showingAlert = true
            return
        }
        
        guard timeToFinish > 0 else {
            alertMessage = "Please enter valid time to finish"
            showingAlert = true
            return
        }
        
        let task = Tasks(
            id: taskToEdit?.id ?? UUID(),
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: dueDate,
            workDate: dueDate,
            importance: importance,
            timeToFinish: timeToFinish
        )
        
        if taskToEdit != nil {
            viewModel.updateTask(task)
        } else {
            viewModel.addTask(task)
        }
        
        dismiss()
    }
}
