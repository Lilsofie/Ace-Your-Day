import Foundation
import RegexBuilder

class TaskViewModel: ObservableObject {
    @Published var tasks: [Tasks] = []
    @Published var recommendations: String?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isUpdated: Bool = false

    
    private let service: APIService
    
    init(apiKey: String = env.apiKey) {
            self.service = APIService(apiKey: apiKey)
        }
    var groupedTasks: [(Date, [Tasks])] {
        let grouped = Dictionary(grouping: tasks) { task in
            Calendar.current.startOfDay(for: task.workDate ?? task.createdAt)
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    func taskExists(id: UUID) -> Bool {
        return tasks.contains { $0.id == id }
    }
    
    func getTaskIndex(by id: UUID) -> Int? {
        return tasks.firstIndex(where: {$0.id == id})!
    }
    
    func addTask(_ task: Tasks) {
        tasks.append(task)
    }
    
    func updateTask(_ task: Tasks) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            isUpdated.toggle()
        }
    }
    
    func toggleTaskCompletion(_ task: Tasks) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }
    
    func deleteTask(_ task: Tasks) {
        tasks.removeAll { $0.id == task.id }
    }
    
    func getTaskDetails(by id: UUID) -> Tasks? {
        return tasks.first { $0.id == id }
    }
    
    func getTaskDetails(by ids: [UUID]) -> [Tasks] {
       return tasks.filter { task in
           ids.contains(task.id)
       }
    }
    
    func updateMultipleTasks(_ updatedTasks: [Tasks]) {
        for updatedTask in updatedTasks {
            print("updated\n",updatedTask)
            updateTask(updatedTask)
        }
        objectWillChange.send()
    }
    
    @MainActor
    func handleError(_ error: Error) {
        self.error = error.localizedDescription
    }
   
    @MainActor
    func getRecommendations() async throws {
       isLoading = true
       defer { isLoading = false }

       let incompleteTasks = tasks.filter { !$0.isCompleted }
       
       do {
           let recommendations = try await service.getTaskRecommendations(for: incompleteTasks)
           self.recommendations = recommendations
           self.error = nil
       } catch {
           self.error = error.localizedDescription
           throw error
       }
   }
    
   @MainActor
    func acceptRecommendations() async {
        guard let recommendations = recommendations else { return }
        isLoading = true
        defer { isLoading = false }
        
        let orderedTasks = parseRecommendations(recommendations)
        var reorderedTasks: [Tasks] = []
        var updatedTasks = tasks
        
        for (_, suggestedDate, suggestedTimeStr, taskId) in orderedTasks {
            guard let uuid = UUID(uuidString: taskId) else {
                print("Invalid UUID string: \(taskId)")
                continue
            }
            let taskIndex = getTaskIndex(by: uuid)
            let scheduledTime = parseDateAndTimeString(suggestedDate, suggestedTimeStr)
            
            var task = updatedTasks[taskIndex!]
            task.workDate = scheduledTime
            updatedTasks[taskIndex!] = task
            reorderedTasks.append(task)
            
        }
            // Add any remaining tasks that weren't in the recommendations
            let remainingTasks = tasks.filter { task in
                !reorderedTasks.contains(where: { $0.id == task.id })
            }
            reorderedTasks.append(contentsOf: remainingTasks)
            
            self.tasks = updatedTasks
            updateMultipleTasks(reorderedTasks)
           
            self.recommendations = nil
            self.error = nil
    }
   
   private func parseRecommendations(_ recommendations: String) -> [(taskTitle: String, suggestedDate: String, suggestedTime: String, taskId: String)] {
       let pattern = /Task:\s(.+?)\s+at\s+([A-Za-z]{3,9}\s\d{1,2},\s\d{4})\s+at\s+([0-9]{1,2}:[0-9]{2}\s[APM]{2}),\s+task id:\s+([A-F0-9-]+)/
       
       return recommendations
           .components(separatedBy: .newlines)
           .compactMap { line -> (taskTitle: String,suggestedDate: String, suggestedTime: String, taskId: String)? in
               guard let match = line.firstMatch(of: pattern),
                     !match.output.1.isEmpty else {
                   return nil
               }
               return (
                   taskTitle: String(match.output.1),
                   suggestedDate: String(match.output.2),
                   suggestedTime: String(match.output.3),
                   taskId: String(match.output.4)
               )
           }
   }
   
    private func parseDateAndTimeString(_ dateString: String, _ timeString: String) -> Date? {
        let calendar = Calendar.current
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let dateFormats = ["MMM d, yyyy", "MMM dd, yyyy", "MMM d yyyy", "MMM dd yyyy", "MMM d", "MMM dd"]
        
        var parsedDate: Date?
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                parsedDate = date
                break
            }
        }
        
        guard let unwrappedParsedDate = parsedDate else {
            print("Failed to parse date string: \(dateString)")
            print("Supported formats: MMM d, yyyy | MMM d")
            return nil
        }
        
        let parsedYear = calendar.component(.year, from: unwrappedParsedDate)
        let fullDate: Date
        if parsedYear == 2024 {
            let currentYear = calendar.component(.year, from: Date())
            guard let dateWithYear = calendar.date(bySetting: .year, value: currentYear, of: unwrappedParsedDate) else {
                print("Failed to set year for date: \(unwrappedParsedDate)")
                return nil
            }
            fullDate = dateWithYear
        } else {
            fullDate = unwrappedParsedDate
        }
        
        let normalizedTimeString = timeString
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let containsAMPM = normalizedTimeString.contains("AM") || normalizedTimeString.contains("PM")
        let timeFormats = containsAMPM
            ? ["h:mm a", "h:mma", "ha"] // 12-hour formats
            : ["HH:mm", "H:mm", "HH:mm:ss"] // 24-hour formats

        var parsedTime: Date?
        for format in timeFormats {
            timeFormatter.dateFormat = format
            if let time = timeFormatter.date(from: normalizedTimeString) {
                parsedTime = time
                break
            }
        }
        
        guard let unwrappedParsedTime = parsedTime else {
           print("Failed to parse time string: \(timeString)")
           return nil
       }
        let timeComponents = calendar.dateComponents([.hour, .minute], from: unwrappedParsedTime)
        
        guard let finalDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0,
                                                 of: fullDate) else {
            print("Failed to combine date and time")
            return nil
        }
        
        return finalDateTime
    }
}
