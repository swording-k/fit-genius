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
                // 坚持天数大卡片
                if let profile = profiles.first, profile.streakDays > 0 {
                    StreakDaysCard(streakDays: profile.streakDays)
                }
                
                // 统计卡片
                StatsCardsView(viewModel: viewModel)
                
                // 重量增长图表（仅显示有重量的动作）
                WeightProgressChartsView(viewModel: viewModel)
                
                // 动作筛选
                ExerciseFilterView(viewModel: viewModel)
                
                // 训练坚持情况（按日期）
                if !viewModel.dailyStats.isEmpty {
                    TrainingConsistencyView(viewModel: viewModel)
                }
                
                // 训练容量趋势
                if !viewModel.trainingData.isEmpty {
                    VolumeChartView(viewModel: viewModel)
                }
                
                // 最近训练记录
                RecentTrainingListView(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("训练统计")
        .onAppear {
            viewModel.loadData()
        }
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
                Text("你坚持训练计划已经")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakDays)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                    Text("天")
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
                    title: "训练天数",
                    value: "\(viewModel.trainingDays)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "完成动作",
                    value: "\(viewModel.totalExercises)",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "总组数",
                    value: "\(viewModel.totalSets)",
                    icon: "repeat",
                    color: .orange
                )
                
                StatCard(
                    title: "训练容量",
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
            
            Text(title)
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
            Text("筛选动作")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableExercises, id: \.self) { exercise in
                        Button(action: {
                            viewModel.filterByExercise(exercise)
                        }) {
                            Text(exercise)
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
            Text("训练坚持情况")
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
            Text(viewModel.selectedExercise == "全部" ? "总训练容量趋势" : "\(viewModel.selectedExercise) 容量趋势")
                .font(.headline)
            
            if viewModel.trainingData.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(viewModel.trainingData) { data in
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
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month().day())
                                    .font(.caption2)
                            }
                        }
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
            Text("最近训练记录")
                .font(.headline)
            
            if viewModel.trainingData.isEmpty {
                Text("暂无训练记录")
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
                    Text("组")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.0f", data.reps))
                        .font(.subheadline)
                        .bold()
                    Text("次")
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
                
                Text("容量: \(String(format: "%.0f", data.volume))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
