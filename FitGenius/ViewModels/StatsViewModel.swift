import Foundation
import SwiftData
import Combine

// MARK: - 训练数据点
struct TrainingDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let exerciseName: String
    let sets: Int
    let reps: Double
    let weight: Double
    let volume: Double // Sets * Reps * Weight (如果weight=0则用Sets*Reps)
}

// MARK: - 每日训练统计
struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let completedExercises: Int
    let totalSets: Int
}

// MARK: - 统计 ViewModel
@MainActor
class StatsViewModel: ObservableObject {
    @Published var selectedExercise: String = "全部"
    @Published var trainingData: [TrainingDataPoint] = []
    @Published var dailyStats: [DailyStats] = []
    @Published var availableExercises: [String] = ["全部"]
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - 加载数据
    func loadData() {
        // 获取所有 ExerciseLog
        let descriptor = FetchDescriptor<ExerciseLog>(
            sortBy: [SortDescriptor(\.date)]
        )
        
        guard let logs = try? modelContext.fetch(descriptor) else {
            return
        }
        
        // 提取所有动作名称和数据点
        var exerciseNames = Set<String>()
        var dataPoints: [TrainingDataPoint] = []
        var dailyStatsDict: [Date: (count: Int, sets: Int)] = [:]
        
        for log in logs {
            guard let exercise = log.exercise else { continue }
            
            exerciseNames.insert(exercise.name)
            
            // 解析次数
            let repsValue = parseReps(log.actualReps)
            
            // 计算训练容量
            // 如果有重量，用 Sets * Reps * Weight
            // 如果没有重量（如引体向上），用 Sets * Reps
            let volume: Double
            if log.actualWeight > 0 {
                volume = Double(log.actualSets) * repsValue * log.actualWeight
            } else {
                volume = Double(log.actualSets) * repsValue
            }
            
            let dataPoint = TrainingDataPoint(
                date: log.date,
                exerciseName: exercise.name,
                sets: log.actualSets,
                reps: repsValue,
                weight: log.actualWeight,
                volume: volume
            )
            dataPoints.append(dataPoint)
            
            // 统计每日数据
            let dayStart = Calendar.current.startOfDay(for: log.date)
            if var stats = dailyStatsDict[dayStart] {
                stats.count += 1
                stats.sets += log.actualSets
                dailyStatsDict[dayStart] = stats
            } else {
                dailyStatsDict[dayStart] = (count: 1, sets: log.actualSets)
            }
        }
        
        // 更新可用动作列表
        availableExercises = ["全部"] + exerciseNames.sorted()
        
        // 根据选择筛选数据
        if selectedExercise == "全部" {
            trainingData = dataPoints
        } else {
            trainingData = dataPoints.filter { $0.exerciseName == selectedExercise }
        }
        
        // 更新每日统计
        dailyStats = dailyStatsDict.map { date, stats in
            DailyStats(date: date, completedExercises: stats.count, totalSets: stats.sets)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - 解析次数字符串
    private func parseReps(_ repsString: String) -> Double {
        // 处理 "8-12" 这样的范围，取平均值
        if repsString.contains("-") {
            let components = repsString.split(separator: "-")
            if components.count == 2,
               let min = Double(components[0].trimmingCharacters(in: .whitespaces)),
               let max = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                return (min + max) / 2.0
            }
        }
        
        // 处理纯数字
        if let value = Double(repsString) {
            return value
        }
        
        // 默认返回 10
        return 10.0
    }
    
    // MARK: - 筛选动作
    func filterByExercise(_ exerciseName: String) {
        selectedExercise = exerciseName
        loadData()
    }
    
    // MARK: - 计算总训练容量
    var totalVolume: Double {
        trainingData.reduce(0) { $0 + $1.volume }
    }
    
    // MARK: - 计算平均训练容量
    var averageVolume: Double {
        guard !trainingData.isEmpty else { return 0 }
        return totalVolume / Double(trainingData.count)
    }
    
    // MARK: - 训练天数
    var trainingDays: Int {
        dailyStats.count
    }
    
    // MARK: - 总完成动作数
    var totalExercises: Int {
        trainingData.count
    }
    
    // MARK: - 总组数
    var totalSets: Int {
        trainingData.reduce(0) { $0 + $1.sets }
    }
    
    // MARK: - 获取特定动作的重量增长数据
    func getWeightProgress(for exerciseName: String) -> [TrainingDataPoint] {
        trainingData
            .filter { $0.exerciseName == exerciseName && $0.weight > 0 }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - 获取特定动作的组数增长数据
    func getSetsProgress(for exerciseName: String) -> [TrainingDataPoint] {
        trainingData
            .filter { $0.exerciseName == exerciseName }
            .sorted { $0.date < $1.date }
    }
}
