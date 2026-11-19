import XCTest
@testable import ScreenTutor

final class StudyPlanTests: XCTestCase {
    func testPlanUsesChosenDaysAndIncludesUpcomingSpacedReviews() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: now)
        var known = Subskill(name: "Gradient")
        known.level = 4
        known.dueAt = calendar.date(byAdding: .day, value: 2, to: today)
        let topic = Topic(id: "optimization", title: "Optimization", subskills: [Subskill(name: "Direction"), known, Subskill(name: "Step size")], createdAt: now, updatedAt: now)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 5, to: today))
        let plan = try StudyPlanBuilder.build(objective: "Explain the update", targetDate: end, topics: [topic], now: now, calendar: calendar)
        XCTAssertEqual(plan.items.count, 3)
        XCTAssertTrue(plan.items.allSatisfy { $0.scheduledDate >= today && $0.scheduledDate <= end })
        XCTAssertLessThanOrEqual(try XCTUnwrap(plan.items.first { $0.subskill == "Gradient" }?.scheduledDate), try XCTUnwrap(known.dueAt))
        XCTAssertThrowsError(try StudyPlanBuilder.build(objective: "Past", targetDate: today.addingTimeInterval(-86_400), topics: [topic], now: now))
    }

    func testMultipleCoursesInterleaveWithinBudgetAndProtectRest() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 9))!
        func topic(_ name: String) -> Topic {
            Topic(id: name, title: name, subskills: (1...4).map { Subskill(name: "\(name) \($0)") }, createdAt: now, updatedAt: now)
        }
        let scopes = [CourseStudyScope(courseID: "a", title: "Optimization", topics: [topic("Gradient")]),
                      CourseStudyScope(courseID: "b", title: "Statistics", topics: [topic("Probability")])]
        let preferences = StudySchedulePreferences(dailyMinutes: 30, restStartHour: 22, restEndHour: 8)
        let plan = try StudyPlanBuilder.balanced(scopes: scopes, targetDate: now.addingTimeInterval(86_400), preferences: preferences, now: now, calendar: calendar)
        XCTAssertEqual(plan.items.count, 4)
        XCTAssertEqual(plan.unscheduledCount, 4)
        XCTAssertEqual(plan.items.prefix(2).compactMap(\.courseID), ["a", "b"])
        XCTAssertTrue(plan.items.allSatisfy { !preferences.isRest($0.scheduledDate, calendar: calendar) })
        for (_, day) in Dictionary(grouping: plan.items, by: { calendar.startOfDay(for: $0.scheduledDate) }) {
            XCTAssertLessThanOrEqual(day.reduce(0) { $0 + $1.minutes }, 30)
        }
    }
}
