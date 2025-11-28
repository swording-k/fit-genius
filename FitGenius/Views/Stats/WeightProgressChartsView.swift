// MARK: - 重量增长图表视图
import SwiftUI
import Charts

struct WeightProgressChartsView: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var selectedExercise: String?
    
    var strengthExercises: [String] {
        // 获取所有有重量记录的动作
        let exercises = Set(viewModel.trainingData.filter { $0.weight > 0 }.map { $0.exerciseName })
        return Array(exercises).sorted()
    }
    
    var body: some View {
        if !strengthExercises.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("重量增长趋势")
                    .font(.headline)
                
                // 动作选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(strengthExercises, id: \.self) { exercise in
                            Button(action: {
                                selectedExercise = exercise
                            }) {
                                Text(exercise)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedExercise == exercise ? Color.green : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedExercise == exercise ? .white : .primary
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                
                // 重量增长图表
                if let exercise = selectedExercise ?? strengthExercises.first {
                    let weightData = viewModel.getWeightProgress(for: exercise)
                    
                    if !weightData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(exercise)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let first = weightData.first, let last = weightData.last {
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1f", first.weight))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f kg", last.weight))
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Chart(weightData) { data in
                                LineMark(
                                    x: .value("日期", data.date),
                                    y: .value("重量", data.weight)
                                )
                                .foregroundStyle(.green)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("日期", data.date),
                                    y: .value("重量", data.weight)
                                )
                                .foregroundStyle(.green)
                            }
                            .frame(height: 180)
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
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel {
                                        if let weight = value.as(Double.self) {
                                            Text(String(format: "%.0f", weight))
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Text("暂无\(exercise)的重量记录")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .onAppear {
                selectedExercise = strengthExercises.first
            }
        }
    }
}
