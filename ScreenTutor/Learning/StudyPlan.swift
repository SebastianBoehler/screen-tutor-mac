import Foundation

struct StudyPlan: Codable, Equatable, Sendable {
    let objective: String
    let targetDate: Date
    let items: [StudyPlanItem]
    var unscheduledCount = 0
}

struct StudyPlanItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let topic: String
    let subskill: String
    let scheduledDate: Date
    var courseID: String? = nil
    var courseTitle: String? = nil
    var minutes = 15
}

enum StudyPlanBuilder {
    static func build(objective: String, targetDate: Date, topics: [Topic], now: Date = Date(), calendar: Calendar = .current) throws -> StudyPlan {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: targetDate)
        guard end >= start else { throw CourseLibraryError.invalid("Choose today or a future study date.") }
        let days = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let skills = topics.flatMap { topic in topic.subskills.map { (topic, $0) } }
            .filter { $0.1.level < 4 || ($0.1.dueAt.map { $0 <= end } ?? false) }
        guard !skills.isEmpty else { throw CourseLibraryError.invalid("Map a topic with the tutor first, or wait until a review is due.") }
        let items = try skills.enumerated().map { position, pair in
            let (topic, skill) = pair
            let offset = position * days / skills.count
            guard var date = calendar.date(byAdding: .day, value: offset, to: start) else {
                throw CourseLibraryError.invalid("This study date could not be scheduled.")
            }
            if let due = skill.dueAt, due <= end { date = min(date, max(start, calendar.startOfDay(for: due))) }
            return StudyPlanItem(id: "\(topic.id):\(skill.id)", topic: topic.title, subskill: skill.name, scheduledDate: date)
        }
        return StudyPlan(objective: objective, targetDate: end, items: items.sorted { $0.scheduledDate < $1.scheduledDate })
    }
}
