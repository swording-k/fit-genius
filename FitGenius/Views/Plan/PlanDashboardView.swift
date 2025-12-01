import SwiftUI
import SwiftData

// MARK: - 计划仪表盘主页面
struct PlanDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    
    @State private var selectedDayIndex = 0
    @State private var showResetAlert = false
    @State private var showAddDaySheet = false
    @State private var showDeleteDayAlert = false
    
    var workoutPlan: WorkoutPlan? {
        profiles.reversed().first(where: { $0.workoutPlan != nil })?.workoutPlan
    }
    
    var sortedDays: [WorkoutDay] {
        workoutPlan?.days.sorted(by: { $0.dayNumber < $1.dayNumber }) ?? []
    }
    
    // 获取今天在循环中的位置
    var todayDayIndex: Int {
        return workoutPlan?.getTodayCyclePosition() ?? 0
    }
    
    // 循环信息字符串
    var cycleInfoString: String {
        guard let plan = workoutPlan else { return "" }
        let cycleWeek = plan.getCurrentCycleWeek()
        let cycleDay = todayDayIndex + 1
        return "循环第 \(cycleWeek) 周 · 第 \(cycleDay) 天"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan = workoutPlan, !sortedDays.isEmpty, let profile = profiles.first {
                    // 顶部计划信息
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .font(.title2)
                                    .bold()
                                
                                Text(cycleInfoString)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 坚持天数
                            if profile.streakDays > 0 {
                                HStack(spacing: 4) {
                                    Text("🔥")
                                        .font(.title2)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(profile.streakDays)")
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.orange)
                                        Text("天")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    
                    // 天数选择器（横向滚动）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                                DayTabButton(
                                    day: day,
                                    plan: plan,
                                    isSelected: selectedDayIndex == index
                                ) {
                                    withAnimation {
                                        selectedDayIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // 当前选中的训练日详情
                    TabView(selection: $selectedDayIndex) {
                        ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                            WorkoutDayDetailView(workoutDay: day)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                } else {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无训练计划")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("请先完成用户资料设置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // 重置按钮
                        Button(action: {
                            showResetAlert = true
                        }) {
                            Text("重新设置")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)

                        if let profile = profiles.last {
                            Button(action: { createEmptyPlan(for: profile) }) {
                                Text("创建空白计划")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showAddDaySheet = true }) {
                            Label("新增训练日", systemImage: "plus.circle")
                        }
                        Button(role: .destructive, action: { showDeleteDayAlert = true }) {
                            Label("删除当前天", systemImage: "trash")
                        }
                        Divider()
                        Button(action: { startNewCycle() }) {
                            Label("开始新循环", systemImage: "calendar.badge.plus")
                        }
                        Divider()
                        Button(action: { showResetAlert = true }) {
                            Label("重新设置（清空所有数据）", systemImage: "arrow.clockwise.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("重新设置", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("确认", role: .destructive) {
                    resetOnboarding()
                }
            } message: {
                Text("这将删除所有数据并重新开始。确定要继续吗？")
            }
            .alert("删除当前天", isPresented: $showDeleteDayAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteCurrentDay()
                }
            } message: {
                Text("将删除当前选中的训练日，并自动重排天数。")
            }
            .sheet(isPresented: $showAddDaySheet) {
                AddDaySheet(plan: workoutPlan) { focus, isRest in
                    addDay(focus: focus, isRestDay: isRest)
                }
            }
            .onAppear {
                // 自动定位到今天的训练
                selectedDayIndex = todayDayIndex
                
                // 更新坚持天数
                if let profile = profiles.first {
                    profile.updateStreakDays(workoutPlan: workoutPlan)
                }
            }
            .onChange(of: workoutPlan?.days.flatMap { $0.exercises }.map { $0.isCompleted }) { _, _ in
                // 当任何训练完成状态改变时，更新坚持天数
                if let profile = profiles.first {
                    profile.updateStreakDays(workoutPlan: workoutPlan)
                }
            }
        }
    }
    
    // 新增训练日
    private func addDay(focus: BodyPartFocus, isRestDay: Bool) {
        guard let plan = workoutPlan else { return }
        let nextNumber = (plan.days.map { $0.dayNumber }.max() ?? 0) + 1
        let day = WorkoutDay(dayNumber: nextNumber, focus: isRestDay ? .rest : focus, isRestDay: isRestDay)
        day.plan = plan
        plan.days.append(day)
        modelContext.insert(day)
        selectedDayIndex = max(0, plan.days.count - 1)
    }
    
    // 删除当前训练日并重排 dayNumber
    private func deleteCurrentDay() {
        guard let plan = workoutPlan else { return }
        let sorted = plan.days.sorted(by: { $0.dayNumber < $1.dayNumber })
        guard sorted.indices.contains(selectedDayIndex) else { return }
        let day = sorted[selectedDayIndex]
        modelContext.delete(day)
        let remaining = plan.days.sorted(by: { $0.dayNumber < $1.dayNumber })
        for (idx, d) in remaining.enumerated() { d.dayNumber = idx + 1 }
        selectedDayIndex = min(selectedDayIndex, max(0, remaining.count - 1))
    }
    
    // 开始新循环：重置起始日期与所有勾选
    private func startNewCycle() {
        guard let plan = workoutPlan else { return }
        plan.creationDate = Date()
        for day in plan.days {
            for ex in day.exercises {
                ex.isCompleted = false
                ex.lastCompletedDate = nil
            }
        }
    }
    
    // 重置 Onboarding
    private func resetOnboarding() {
        // 删除所有用户数据
        for profile in profiles {
            modelContext.delete(profile)
        }
        
        // 重置 Onboarding 状态
        hasOnboarded = false
    }

    private func createEmptyPlan(for profile: UserProfile) {
        let plan = WorkoutPlan(name: "我的训练计划")
        plan.userProfile = profile
        profile.workoutPlan = plan
        modelContext.insert(plan)
        try? modelContext.save()
    }
}

// MARK: - 天数选项卡按钮
struct DayTabButton: View {
    let day: WorkoutDay
    let plan: WorkoutPlan
    let isSelected: Bool
    let action: () -> Void
    
    var completedCount: Int {
        day.exercises.filter { $0.isCompleted }.count
    }
    
    var totalCount: Int {
        day.exercises.count
    }
    
    // 获取该天对应的日期
    var dayDate: Date {
        plan.getDateForDay(dayNumber: day.dayNumber)
    }
    
    // 日期字符串（月/日）
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dayDate)
    }
    
    // 星期字符串
    var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: dayDate)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 日期
                Text(dateString)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                // 星期
                Text(weekdayString)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                
                // 训练部位或休息
                if day.isRestDay {
                    Text("休息")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                } else {
                    Text(day.focus.localizedName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
                
                // 进度指示
                if !day.isRestDay && totalCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption2)
                    }
                    .foregroundColor(completedCount == totalCount ? .green : .secondary)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, WorkoutDay.self, Exercise.self, configurations: config)
    
    let profile = UserProfile(name: "张三", age: 25, height: 175, weight: 70, goal: .buildMuscle, environment: .gym)
    let plan = WorkoutPlan(name: "增肌计划")
    profile.workoutPlan = plan
    
    let day1 = WorkoutDay(dayNumber: 1, focus: .chest)
    day1.exercises = [
        Exercise(name: "卧推", sets: 4, reps: "8-12", weight: 60),
        Exercise(name: "飞鸟", sets: 3, reps: "12-15", weight: 20)
    ]
    
    let day2 = WorkoutDay(dayNumber: 2, focus: .back)
    day2.exercises = [
        Exercise(name: "引体向上", sets: 4, reps: "8-12"),
        Exercise(name: "划船", sets: 4, reps: "10-12", weight: 40)
    ]
    
    plan.days = [day1, day2]
    container.mainContext.insert(profile)
    
    return PlanDashboardView()
        .modelContainer(container)
}
