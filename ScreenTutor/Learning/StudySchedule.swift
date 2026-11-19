import Foundation

struct StudySchedulePreferences: Codable, Equatable, Sendable {
    var dailyMinutes = 45
    var restStartHour = 22
    var restEndHour = 8

    func isRest(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return restStartHour < restEndHour ? (restStartHour..<restEndHour).contains(hour)
            : hour >= restStartHour || hour < restEndHour
    }
}

struct CourseStudyScope: Equatable, Sendable {
    let courseID: String
    let title: String
    let topics: [Topic]
}

extension StudyPlanBuilder {
    /// Interleave courses within the learner's daily budget; never schedule in protected rest.
    static func balanced(scopes: [CourseStudyScope], targetDate: Date, preferences: StudySchedulePreferences,
                         now: Date = Date(), calendar: Calendar = .current) throws -> StudyPlan {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: targetDate)
        guard end >= start, (0..<24).contains(preferences.restStartHour), (0..<24).contains(preferences.restEndHour),
              preferences.restStartHour != preferences.restEndHour, preferences.dailyMinutes >= 15
        else { throw CourseLibraryError.invalid("Choose a future date, at least 15 study minutes, and a valid rest window.") }
        var queues = scopes.map { scope in
            scope.topics.flatMap { topic in topic.subskills.compactMap { skill -> (Topic, Subskill)? in
                skill.level < 4 || (skill.dueAt.map { $0 <= end.addingTimeInterval(86_399) } ?? false) ? (topic, skill) : nil
            } }
        }
        guard queues.contains(where: { !$0.isEmpty }) else { throw CourseLibraryError.invalid("Establish a course learning goal with the tutor before planning.") }
        var items: [StudyPlanItem] = []
        var day = start
        var nextCourse = 0
        while day <= end {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
                  var slot = calendar.date(bySettingHour: preferences.restEndHour, minute: 0, second: 0, of: day)
            else { throw CourseLibraryError.invalid("A study date could not be scheduled.") }
            if day == start, slot < now { slot = now.addingTimeInterval(15 * 60 - now.timeIntervalSince1970.truncatingRemainder(dividingBy: 15 * 60)) }
            var used = 0
            while slot.addingTimeInterval(15 * 60) <= tomorrow, used + 15 <= preferences.dailyMinutes {
                defer { slot = slot.addingTimeInterval(15 * 60) }
                guard !preferences.isRest(slot, calendar: calendar),
                      !preferences.isRest(slot.addingTimeInterval(15 * 60 - 1), calendar: calendar) else { continue }
                var chosen: (course: Int, position: Int)?
                for offset in 0..<scopes.count {
                    let course = (nextCourse + offset) % scopes.count
                    if let position = queues[course].firstIndex(where: { pair in
                        pair.1.level < 4 || (pair.1.dueAt.map { calendar.startOfDay(for: $0) <= day } ?? false)
                    }) { chosen = (course, position); break }
                }
                guard let chosen else { break }
                let (topic, skill) = queues[chosen.course].remove(at: chosen.position)
                let scope = scopes[chosen.course]
                items.append(StudyPlanItem(id: "\(scope.courseID):\(topic.id):\(skill.id)", topic: topic.title,
                    subskill: skill.name, scheduledDate: slot, courseID: scope.courseID, courseTitle: scope.title, minutes: 15))
                nextCourse = (chosen.course + 1) % scopes.count
                used += 15
            }
            day = tomorrow
        }
        return StudyPlan(objective: "Study across your courses", targetDate: end, items: items,
                         unscheduledCount: queues.reduce(0) { $0 + $1.count })
    }
}
