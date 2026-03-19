//
//  FitGeniusWidget.swift
//  FitGeniusWidget
//
//  训练和饮食Widget
//

import WidgetKit
import SwiftUI

// MARK: - 数据模型
struct WidgetExerciseData: Codable, Identifiable {
    var id: String { uuid.uuidString }
    let uuid: UUID
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    let isCompleted: Bool

    init(uuid: UUID = UUID(), name: String, sets: Int, reps: String, weight: Double, isCompleted: Bool) {
        self.uuid = uuid
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }
}

struct WidgetWorkoutData: Codable {
    let dayName: String
    let focus: String
    let exercises: [WidgetExerciseData]
    let isRestDay: Bool
    let cycleWeek: Int
    let cycleDay: Int
}

struct WidgetDietData: Codable {
    let totalCalories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let hasData: Bool
}

enum WidgetBackgroundType: String, Codable {
    case system
    case customImage
}

// MARK: - Timeline Entry
struct FitGeniusEntry: TimelineEntry {
    let date: Date
    let workoutData: WidgetWorkoutData?
    let dietData: WidgetDietData?
    let backgroundType: WidgetBackgroundType
    let customBackgroundData: Data?
    let widgetFamily: WidgetFamily
    let widgetContent: String  // "workout" or "diet"
}

// MARK: - Timeline Provider
struct FitGeniusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FitGeniusEntry {
        FitGeniusEntry(
            date: Date(),
            workoutData: WidgetWorkoutData(
                dayName: "胸部训练",
                focus: "胸大肌",
                exercises: [
                    WidgetExerciseData(name: "卧推", sets: 4, reps: "8-12", weight: 60, isCompleted: true),
                    WidgetExerciseData(name: "哑铃飞鸟", sets: 3, reps: "12-15", weight: 15, isCompleted: false)
                ],
                isRestDay: false,
                cycleWeek: 1,
                cycleDay: 1
            ),
            dietData: WidgetDietData(totalCalories: 1800, protein: 120, carbs: 200, fat: 60, hasData: true),
            backgroundType: .system,
            customBackgroundData: nil,
            widgetFamily: .systemMedium,
            widgetContent: "workout"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FitGeniusEntry) -> Void) {
        let entry = createEntry(family: context.family)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitGeniusEntry>) -> Void) {
        let entry = createEntry(family: context.family)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry(family: WidgetFamily) -> FitGeniusEntry {
        let defaults = UserDefaults(suiteName: "group.com.swordingk.fitgenius")

        var workoutData: WidgetWorkoutData?
        var dietData: WidgetDietData?

        // 读取训练数据
        if let workoutDataEncoded = defaults?.data(forKey: "widgetWorkout") {
            workoutData = try? JSONDecoder().decode(WidgetWorkoutData.self, from: workoutDataEncoded)
        }

        // 读取饮食数据
        if let dietDataEncoded = defaults?.data(forKey: "widgetDiet") {
            dietData = try? JSONDecoder().decode(WidgetDietData.self, from: dietDataEncoded)
        }

        // 读取背景设置
        let bgTypeString = defaults?.string(forKey: "widgetBackgroundType") ?? "system"
        let backgroundType = WidgetBackgroundType(rawValue: bgTypeString) ?? .system
        let customBackground = defaults?.data(forKey: "widgetCustomBackground")

        // 读取Widget内容偏好
        let widgetContent = defaults?.string(forKey: "widgetContent") ?? "workout"

        return FitGeniusEntry(
            date: Date(),
            workoutData: workoutData,
            dietData: dietData,
            backgroundType: backgroundType,
            customBackgroundData: customBackground,
            widgetFamily: family,
            widgetContent: widgetContent
        )
    }
}

// MARK: - Widget配置
struct FitGeniusWidget: Widget {
    let kind: String = "FitGeniusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitGeniusProvider()) { entry in
            FitGeniusWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("FitGenius")
        .description("查看训练和饮食状态")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget主视图
struct FitGeniusWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FitGeniusEntry

    var body: some View {
        ZStack {
            // 背景 - 全屏铺满
            WidgetBackgroundView(
                type: entry.backgroundType,
                customData: entry.customBackgroundData
            )
            .ignoresSafeArea()

            // 根据尺寸显示不同内容
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                MediumWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - 小尺寸视图
struct SmallWidgetView: View {
    var entry: FitGeniusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题栏
            HStack {
                Image(systemName: "figure.run")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("今日训练")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            Divider()

            // 根据用户偏好显示对应内容
            if entry.widgetContent == "diet" {
                // 饮食Widget
                if let diet = entry.dietData, diet.hasData {
                    dietContentView(diet: diet)
                } else {
                    emptyDietView
                }
            } else {
                // 训练Widget (默认)
                if let workout = entry.workoutData {
                    workoutContentView(workout: workout)
                } else {
                    emptyWorkoutView
                }
            }
        }
        .padding(12)
    }

    // MARK: - 饮食内容视图
    @ViewBuilder
    private func dietContentView(diet: WidgetDietData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(diet.totalCalories))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("千卡")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: min(diet.totalCalories / 2000, 1.0))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 40, height: 40)
            }

            Spacer()

            HStack(spacing: 8) {
                dietNutrient(label: "蛋白", value: diet.protein)
                dietNutrient(label: "碳水", value: diet.carbs)
                dietNutrient(label: "脂肪", value: diet.fat)
            }
        }
    }

    private func dietNutrient(label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))g")
                .font(.caption2)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 训练内容视图 - 类似Reminders清单样式
    @ViewBuilder
    private func workoutContentView(workout: WidgetWorkoutData) -> some View {
        if workout.isRestDay {
            // 休息日
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                Text("休息日")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("放松身心")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // 训练日 - 显示未完成的动作清单
            VStack(alignment: .leading, spacing: 3) {
                // 标题
                HStack {
                    Text(workout.focus)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // 未完成的动作列表
                let pendingExercises = workout.exercises.filter { !$0.isCompleted }
                let completedCount = workout.exercises.count - pendingExercises.count
                let totalCount = workout.exercises.count

                if pendingExercises.isEmpty {
                    // 全部完成
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("全部完成!")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 显示未完成的动作（最多显示4个）
                    ForEach(pendingExercises.prefix(4)) { exercise in
                        HStack(spacing: 6) {
                            Circle()
                                .stroke(Color.blue, lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                            Text(exercise.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundColor(.primary)
                    }

                    if pendingExercises.count > 4 {
                        Text("+\(pendingExercises.count - 4)个动作")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 进度提示
                    Text("\(completedCount)/\(totalCount) 已完成")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 空训练视图
    @ViewBuilder
    private var emptyWorkoutView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundColor(.gray)
            Text("暂无训练计划")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空饮食视图
    @ViewBuilder
    private var emptyDietView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.title2)
                .foregroundColor(.gray)
            Text("暂无饮食记录")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 中等尺寸视图
struct MediumWidgetView: View {
    var entry: FitGeniusEntry

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：训练
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                    Text("今日训练")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    if let workout = entry.workoutData, !workout.isRestDay {
                        Text("第\(workout.cycleDay)天")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let workout = entry.workoutData {
                    if workout.isRestDay {
                        VStack {
                            Spacer()
                            Image(systemName: "moon.stars.fill")
                                .font(.largeTitle)
                                .foregroundColor(.indigo)
                            Text("休息日")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("放松身心")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        // 训练日 - 显示未完成的动作列表
                        let pendingExercises = workout.exercises.filter { !$0.isCompleted }
                        let completedCount = workout.exercises.count - pendingExercises.count
                        let totalCount = workout.exercises.count

                        if pendingExercises.isEmpty {
                            // 全部完成
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                                Text("全部完成!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(completedCount)/\(totalCount) 动作")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            // 显示未完成的动作
                            Text(workout.focus)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Spacer()

                            // 显示未完成的动作（最多4个）
                            ForEach(pendingExercises.prefix(4)) { exercise in
                                HStack(spacing: 6) {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 1.5)
                                        .frame(width: 12, height: 12)
                                    Text(exercise.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(exercise.sets)组")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if pendingExercises.count > 4 {
                                Text("+\(pendingExercises.count - 4)个动作")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // 进度
                            HStack(spacing: 6) {
                                ProgressView(value: Double(completedCount), total: Double(totalCount))
                                    .tint(completedCount == totalCount ? .green : .blue)
                                Text("\(completedCount)/\(totalCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "figure.run")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无计划")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // 右侧：饮食
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.orange)
                    Text("今日饮食")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                if let diet = entry.dietData, diet.hasData {
                    Text("\(Int(diet.totalCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 营养素
                    VStack(alignment: .leading, spacing: 4) {
                        nutritionRow(label: "蛋白质", value: diet.protein, color: .red)
                        nutritionRow(label: "碳水", value: diet.carbs, color: .blue)
                        nutritionRow(label: "脂肪", value: diet.fat, color: .yellow)
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func nutritionRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(value))g")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 大尺寸视图
struct LargeWidgetView: View {
    var entry: FitGeniusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FitGenius")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if let workout = entry.workoutData, !workout.isRestDay {
                    Text("第\(workout.cycleWeek)周 · 第\(workout.cycleDay)天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 训练部分
            if let workout = entry.workoutData {
                if workout.isRestDay {
                    VStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.indigo)
                        Text("休息日")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("放松身心，明日再战")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 显示未完成的动作
                    let pendingExercises = workout.exercises.filter { !$0.isCompleted }
                    let completedCount = workout.exercises.count - pendingExercises.count
                    let totalCount = workout.exercises.count

                    if pendingExercises.isEmpty {
                        // 全部完成
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("太棒了！全部完成")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("\(completedCount) 个动作已完成")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // 显示待办清单
                        HStack {
                            Text(workout.focus)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(completedCount)/\(totalCount) 完成")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 显示未完成的动作
                        ForEach(pendingExercises) { exercise in
                            HStack(spacing: 10) {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                Text(exercise.name)
                                    .font(.body)
                                Spacer()
                                Text("\(exercise.sets)组 \(exercise.reps)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 如果还有更多
                        if pendingExercises.count > 6 {
                            Text("+\(pendingExercises.count - 6) 个动作未显示")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 进度条
                        VStack(spacing: 4) {
                            ProgressView(value: Double(completedCount), total: Double(totalCount))
                                .tint(completedCount == totalCount ? .green : .blue)
                            Text("\(completedCount)/\(totalCount) 已完成")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("暂无训练计划")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 饮食部分
            if let diet = entry.dietData, diet.hasData {
                HStack {
                    VStack(alignment: .leading) {
                        Text("今日摄入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(diet.totalCalories))")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        NutrientRow(label: "蛋白质", value: diet.protein, color: .red)
                        NutrientRow(label: "碳水", value: diet.carbs, color: .blue)
                        NutrientRow(label: "脂肪", value: diet.fat, color: .yellow)
                    }
                }
            } else {
                Text("暂无饮食记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - 营养素组件
struct NutrientPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        Text("\(label): \(value)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }
}

struct NutrientRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(value))g")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 背景视图
struct WidgetBackgroundView: View {
    let type: WidgetBackgroundType
    let customData: Data?

    var body: some View {
        Group {
            switch type {
            case .system:
                Color(.systemBackground)
            case .customImage:
                if let data = customData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(.systemBackground)
                }
            }
        }
        .ignoresSafeArea()
    }
}
