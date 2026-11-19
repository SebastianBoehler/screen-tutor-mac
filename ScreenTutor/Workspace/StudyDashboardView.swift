import SwiftUI

struct StudyDashboardView: View {
    let model: AppModel
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 6, to: Date())!
    @State private var errorMessage: String?
    @State private var scopes: [CourseStudyScope] = []
    @State private var preferences = StudySchedulePreferences()

    private var topics: [Topic] {
        var seen = Set<String>()
        return scopes.flatMap(\.topics).filter { seen.insert($0.id).inserted }
    }
    private var skills: [Subskill] { topics.flatMap(\.subskills) }
    private var independent: Int { skills.filter { $0.level >= 4 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your learning").font(.largeTitle.weight(.semibold))
                    Text(scopes.isEmpty ? "Set a concrete learning goal with your tutor to begin." : "\(scopes.count) courses · independent checks and spaced review")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 36) {
                    metric("Independent", value: "\(independent)/\(skills.count)")
                    metric("Due for review", value: "\(skills.filter { $0.isDue(at: Date()) }.count)")
                    if let session = model.learner.currentSession {
                        metric("Unaided checks", value: "\(session.warmUpPassed + session.exitPassed)/\(session.warmUpPassed + session.warmUpFailed + session.exitPassed + session.exitFailed)")
                    }
                }
                if !skills.isEmpty { ProgressView(value: Double(independent), total: Double(skills.count)).tint(.accentColor) }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Concept map").font(.title2.weight(.semibold))
                    if topics.isEmpty {
                        Text("The tutor maps your topic into small subskills after you establish a goal. Nothing is marked independent until your checks support it.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(topics) { topic in
                        Text(topic.title).font(.headline).padding(.top, 4)
                        ForEach(topic.subskills) { skill in
                            HStack {
                                Image(systemName: skill.level >= 4 ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(skill.level >= 4 ? Color.green : Color.secondary)
                                Text(skill.name)
                                Spacer()
                                Text(LearnerRules.levelName(skill.level)).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 3)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your study plan").font(.title2.weight(.semibold))
                    HStack {
                        DatePicker("Study toward", selection: $targetDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        Spacer()
                        Button(model.courses.studyPlan == nil ? "Make plan" : "Adjust plan") { makePlan() }
                            .disabled(topics.isEmpty)
                    }
                    HStack(spacing: 20) {
                        Stepper("\(preferences.dailyMinutes) study minutes / day", value: $preferences.dailyMinutes, in: 15...240, step: 15)
                        Spacer()
                        Text("Rest").foregroundStyle(.secondary)
                        hourPicker("Rest starts", selection: $preferences.restStartHour)
                        Text("–").foregroundStyle(.secondary)
                        hourPicker("Rest ends", selection: $preferences.restEndHour)
                    }
                    Text("Spread unfinished concepts and upcoming reviews across the days you choose. Adjust the date as your workload changes.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let plan = model.courses.studyPlan {
                        ForEach(plan.items) { item in
                            HStack(alignment: .top) {
                                Text(item.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                                    .font(.caption.monospaced()).frame(width: 155, alignment: .leading)
                                Text(item.subskill)
                                Spacer()
                                Text(item.courseTitle ?? item.topic).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        if plan.unscheduledCount > 0 {
                            Text("\(plan.unscheduledCount) concepts do not fit this budget. Extend the date or adjust your daily time.")
                                .font(.callout).foregroundStyle(.orange)
                        }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                Text("Plans use estimated 15-minute blocks and protect your chosen rest window. Sleep is not measured. Assisted practice and independent learning evidence stay separate.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 850, alignment: .leading)
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            preferences = model.courses.studyPreferences
            if let date = model.courses.studyPlan?.targetDate, date >= Date() { targetDate = date }
            reloadScopes()
        }
        .onChange(of: model.learner.state) { reloadScopes() }
        .onChange(of: model.workspace.learningGoal) { reloadScopes() }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 28, weight: .medium, design: .rounded)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func makePlan() {
        do {
            let plan = try StudyPlanBuilder.balanced(scopes: scopes, targetDate: targetDate, preferences: preferences)
            try model.courses.setStudySchedule(preferences: preferences, plan: plan)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func reloadScopes() {
        do {
            scopes = try model.courses.courses.compactMap { course in
                guard let goal = try model.workspace.goal(forCourse: course.id),
                      let topic = model.learner.state.topics.first(where: { $0.id == LearnerRules.slug(goal.topic) }) else { return nil }
                return CourseStudyScope(courseID: course.id, title: course.title, topics: [topic])
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func hourPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
        }.labelsHidden().frame(width: 85).accessibilityLabel(title)
    }
}
