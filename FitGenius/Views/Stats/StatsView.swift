import SwiftUI
import SwiftData
import Charts

// MARK: - 统计视图
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var viewModel: StatsViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.allTrainingData.isEmpty {
                    StatsEmptyState()
                } else {
                    // 坚持天数大卡片
                    if let profile = profiles.first, profile.streakDays > 0 {
                        StreakDaysCard(streakDays: profile.streakDays)
                    }

                    StatsCardsView(viewModel: viewModel)

                    // 动作筛选仅影响趋势和最近记录，总览始终展示完整数据。
                    ExerciseFilterView(viewModel: viewModel)

                    VolumeChartView(viewModel: viewModel)

                    // 重量增长图表（仅显示有重量的动作）
                    WeightProgressChartsView(viewModel: viewModel)

                    RecentTrainingListView(viewModel: viewModel)
                }
            }
            .padding()
        }
        .navigationTitle("training_stats")
        .onAppear {
            viewModel.loadData()
        }
    }
}

struct StatsEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            "no_training_record",
            systemImage: "chart.xyaxis.line",
            description: Text("stats_empty_description")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - 坚持天数卡片
struct StreakDaysCard: View {
    let streakDays: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 50))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("streak_message")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakDays)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                    Text("days")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - 统计卡片
struct StatsCardsView: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: "training_days",
                    value: "\(viewModel.trainingDays)",
                    icon: "calendar",
                    color: .blue
                )

                StatCard(
                    title: "completed_exercises",
                    value: "\(viewModel.totalExercises)",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "total_sets",
                    value: "\(viewModel.totalSets)",
                    icon: "repeat",
                    color: .orange
                )

                StatCard(
                    title: "volume",
                    value: String(format: "%.0f", viewModel.totalVolume),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - 单个统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 动作筛选器
struct ExerciseFilterView: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("filter_exercise")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableExercises, id: \.self) { exercise in
                        Button(action: {
                            viewModel.filterByExercise(exercise)
                        }) {
                            Text(exercise == StatsViewModel.allExercisesFilter ? "all_exercises" : exercise)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedExercise == exercise ? Color.blue : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    viewModel.selectedExercise == exercise ? .white : .primary
                                )
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 训练坚持情况视图
struct TrainingConsistencyView: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("training_consistency")
                .font(.headline)
            
            Chart(viewModel.dailyStats) { stat in
                BarMark(
                    x: .value("日期", stat.date, unit: .day),
                    y: .value("完成动作数", stat.completedExercises)
                )
                .foregroundStyle(.green)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month().day())
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 训练容量趋势图
struct VolumeChartView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                viewModel.selectedExercise == StatsViewModel.allExercisesFilter
                    ? "total_volume_trend".localized
                    : String(format: "exercise_volume_trend".localized, viewModel.selectedExercise)
            )
                .font(.headline)

            if viewModel.trainingData.isEmpty {
                Text("no_data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(viewModel.volumeTrendData) { data in
                    AreaMark(
                        x: .value("日期", data.date),
                        y: .value("容量", data.volume)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", data.date),
                        y: .value("容量", data.volume)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", data.date),
                        y: .value("容量", data.volume)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(data.id == viewModel.volumeTrendData.last?.id ? 80 : 30)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let volume = value.as(Double.self) {
                                Text("\(Int(volume))")
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 最近训练记录列表
struct RecentTrainingListView: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recent_training")
                .font(.headline)

            if viewModel.trainingData.isEmpty {
                Text("no_training_record")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.trainingData.suffix(10).reversed()) { data in
                    TrainingRecordRow(data: data)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 训练记录行
struct TrainingRecordRow: View {
    let data: TrainingDataPoint
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.exerciseName)
                    .font(.headline)
                
                Text(data.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(data.sets)")
                        .font(.subheadline)
                        .bold()
                    Text("sets")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("×")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.0f", data.reps))
                        .font(.subheadline)
                        .bold()
                    Text("reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if data.weight > 0 {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", data.weight))
                            .font(.subheadline)
                            .bold()
                        Text("kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("volume: \(String(format: "%.0f", data.volume))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
