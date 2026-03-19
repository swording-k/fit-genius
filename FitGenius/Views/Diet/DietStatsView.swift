import SwiftUI
import SwiftData
import Charts
import Combine

struct DietStatsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DietStatsViewModel

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: DietStatsViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 今日营养摄入卡片
                HStack(spacing: 12) {
                    StatCard(title: "今日热量", value: String(format: "%.0f", viewModel.todayCalories), icon: "flame", color: .orange)
                    StatCard(title: "今日蛋白(g)", value: String(format: "%.0f", viewModel.todayProtein), icon: "bolt", color: .blue)
                }
                HStack(spacing: 12) {
                    StatCard(title: "今日碳水(g)", value: String(format: "%.0f", viewModel.todayCarbs), icon: "car.fill", color: .purple)
                    StatCard(title: "今日脂肪(g)", value: String(format: "%.0f", viewModel.todayFat), icon: "drop", color: .pink)
                }

                if !viewModel.todayNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("饮食建议").font(.headline)
                        Text(viewModel.todayNotes).foregroundColor(.secondary)
                    }
                }

                // 热量趋势综合图表
                if !viewModel.points.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热量趋势").font(.headline)
                        Chart(viewModel.points) { p in
                            AreaMark(
                                x: .value("日期", p.date),
                                y: .value("热量", p.calories)
                            )
                            .foregroundStyle(.orange.opacity(0.2))

                            LineMark(
                                x: .value("日期", p.date),
                                y: .value("热量", p.calories)
                            )
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("日期", p.date),
                                y: .value("热量", p.calories)
                            )
                            .foregroundStyle(.orange)
                            .symbolSize(p == viewModel.points.last ? 80 : 30)
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
                                AxisValueLabel()
                                AxisGridLine()
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)

                    // 宏量营养素综合图表
                    VStack(alignment: .leading, spacing: 12) {
                        Text("宏量营养素趋势").font(.headline)

                        // 图例
                        HStack(spacing: 16) {
                            LegendItem(color: .blue, label: "蛋白质")
                            LegendItem(color: .purple, label: "碳水")
                            LegendItem(color: .pink, label: "脂肪")
                        }

                        Chart(viewModel.points) { p in
                            AreaMark(
                                x: .value("日期", p.date),
                                y: .value("蛋白质", p.protein)
                            )
                            .foregroundStyle(.blue.opacity(0.2))

                            LineMark(
                                x: .value("日期", p.date),
                                y: .value("蛋白质", p.protein)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("日期", p.date),
                                y: .value("碳水", p.carbs)
                            )
                            .foregroundStyle(.purple.opacity(0.2))

                            LineMark(
                                x: .value("日期", p.date),
                                y: .value("碳水", p.carbs)
                            )
                            .foregroundStyle(.purple)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("日期", p.date),
                                y: .value("脂肪", p.fat)
                            )
                            .foregroundStyle(.pink.opacity(0.2))

                            LineMark(
                                x: .value("日期", p.date),
                                y: .value("脂肪", p.fat)
                            )
                            .foregroundStyle(.pink)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("日期", p.date),
                                y: .value("蛋白质", p.protein)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(20)

                            PointMark(
                                x: .value("日期", p.date),
                                y: .value("碳水", p.carbs)
                            )
                            .foregroundStyle(.purple)
                            .symbolSize(20)

                            PointMark(
                                x: .value("日期", p.date),
                                y: .value("脂肪", p.fat)
                            )
                            .foregroundStyle(.pink)
                            .symbolSize(20)
                        }
                        .frame(height: 220)
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
                                AxisValueLabel()
                                AxisGridLine()
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无饮食记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("开始记录饮食后，这里将展示你的营养趋势")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .navigationTitle("饮食统计")
        .onAppear { viewModel.loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .dietSummaryUpdated)) { _ in
            viewModel.loadData()
        }
    }
}

// MARK: - 图例项
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}