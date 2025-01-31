import Foundation

struct Tasks: Identifiable, Codable {
    var id = UUID()
    var title: String   // title of the task (required)
    var description: String? // description of the task (optional)
    var dueDate: Date? // due date task (set to today as default)
    var workDate: Date? // date that the task will be work on
    var importance: ImportanceLevel // importance level (set to medium as default)
    var timeToFinish: Double // in hours
    var isCompleted: Bool = false
    var createdAt: Date = Date()
}

enum ImportanceLevel: String, Codable, CaseIterable{
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}
