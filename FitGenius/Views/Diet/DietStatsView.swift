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
                VStack(alignment: .leading, spacing: 12) {
                    Text("每日热量趋势").font(.headline)
                    Chart(viewModel.points) { p in
                        LineMark(x: .value("日期", p.date), y: .value("热量", p.calories))
                        PointMark(x: .value("日期", p.date), y: .value("热量", p.calories))
                    }
                    .frame(height: 200)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("每日蛋白质趋势").font(.headline)
                    Chart(viewModel.points) { p in
                        LineMark(x: .value("日期", p.date), y: .value("蛋白质", p.protein))
                            .foregroundStyle(.blue)
                        PointMark(x: .value("日期", p.date), y: .value("蛋白质", p.protein))
                            .foregroundStyle(.blue)
                    }
                    .frame(height: 200)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("每日碳水趋势").font(.headline)
                    Chart(viewModel.points) { p in
                        LineMark(x: .value("日期", p.date), y: .value("碳水", p.carbs))
                            .foregroundStyle(.purple)
                        PointMark(x: .value("日期", p.date), y: .value("碳水", p.carbs))
                            .foregroundStyle(.purple)
                    }
                    .frame(height: 200)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("每日脂肪趋势").font(.headline)
                    Chart(viewModel.points) { p in
                        LineMark(x: .value("日期", p.date), y: .value("脂肪", p.fat))
                            .foregroundStyle(.pink)
                        PointMark(x: .value("日期", p.date), y: .value("脂肪", p.fat))
                            .foregroundStyle(.pink)
                    }
                    .frame(height: 200)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("宏量营养素趋势").font(.headline)
                    Chart {
                        ForEach(viewModel.points) { p in
                            LineMark(x: .value("日期", p.date), y: .value("蛋白质", p.protein)).foregroundStyle(.blue)
                            LineMark(x: .value("日期", p.date), y: .value("碳水", p.carbs)).foregroundStyle(.purple)
                            LineMark(x: .value("日期", p.date), y: .value("脂肪", p.fat)).foregroundStyle(.pink)
                        }
                    }
                    .frame(height: 200)
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