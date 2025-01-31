import Foundation
import SwiftUI

struct APIService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    struct Request: Codable {
        var model: String = "claude-3-sonnet-20240229"
        var max_tokens: Int = 1024
        let messages: [Message]
        
        struct Message: Codable {
            var role: String = "user"
            let content: String
        }
    }
    
    struct Response: Decodable {
        let content: [Content]
        
        struct Content: Decodable {
            let text: String
        }
    }
    
    func getTaskRecommendations(for tasks: [Tasks]) async throws -> String {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let prompt = createPrompt(for: incompleteTasks)
        let message = Request.Message(content: prompt)
        let request = Request(messages: [message])
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("API Error: \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(Response.self, from: data)
            return apiResponse.content.first?.text ?? "No recommendations available"
        } catch {
            print("Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func createPrompt(for tasks: [Tasks]) -> String {
        let taskDescriptions = tasks.map { task in
            """
            Task: \(task.title)
            ID: \(task.id)
            Description: \(task.description ?? "N/A")
            Due Date: \(formatDate(task.dueDate))
            Time Required: \(task.timeToFinish) hours
            Importance: \(task.importance.rawValue)
            Status: \(task.isCompleted ? "Completed" : "Pending")
            Created: \(formatDate(task.createdAt))
            """
        }.joined(separator: "\n\n")
        
        if taskDescriptions.isEmpty{
            return "No tasks avaliable"
        }
        
        let prompt = """
        The following are tasks in my task management app:
        
        \(taskDescriptions)
        
        Based task details provided, analyze these tasks and provide:
        1. Recommend task execution order
        2. Time management suggestions considering due dates and time required

        Here are some notes that needs to be consider:
        Due Dates are strict due dates
        Try to keep the suggestion response clear and simple so that it's easy to take 
        Try to optimize the time management, ideally we want every task to finish one day prior to the due date
        Try to do all the tasks be between working hours
        No need for conclusion
        Consider both importance & due date 
        Check today's date, one of your recommendation date should be before today
        
        
        Below is the expected response format:
        The recommended order is:
        1) {task title} at {Date} at {Time}, task id: {task id}
        2) {tast title} at {Date} at {Time}, task id: {task id}
        Some other suggestion would be: {your suggesstion 3.4}
        """
        return prompt
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "No date set" }
        return Self.dateFormatter.string(from: date)
    }
    
}
