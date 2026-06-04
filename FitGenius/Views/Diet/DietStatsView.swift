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
            VStack(alignment: .leading, spacing: 20) {
                todaySummary

                if !viewModel.todayNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("diet_advice").font(.headline)
                        Text(viewModel.todayNotes).foregroundColor(.secondary)
                    }
                }

                if viewModel.points.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("calorie_trend").font(.headline)
                        Chart(viewModel.points) { p in
                            LineMark(
                                x: .value("date", p.date),
                                y: .value("calories", p.calories)
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("date", p.date),
                                y: .value("calories", p.calories)
                            )
                            .foregroundStyle(.orange)
                            .symbolSize(p == viewModel.points.last ? 70 : 30)
                        }
                        .frame(height: 190)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }

                if !viewModel.points.isEmpty {
                    macroSummary
                    recentRecords
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("no_diet_record")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("start_logging_diet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .navigationTitle("diet_stats")
        .onAppear { viewModel.loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .dietSummaryUpdated)) { _ in
            viewModel.loadData()
        }
    }

    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("today_nutrition").font(.headline)
                Spacer()
                Text(String(format: NSLocalizedString("diet_days_logged_format", comment: ""), viewModel.points.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", viewModel.todayCalories))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("kcal").foregroundColor(.secondary)
            }
            HStack(spacing: 10) {
                NutritionPill(title: "protein", value: viewModel.todayProtein, color: .blue)
                NutritionPill(title: "carbs", value: viewModel.todayCarbs, color: .green)
                NutritionPill(title: "fat", value: viewModel.todayFat, color: .pink)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var macroSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("today_macro_distribution").font(.headline)
            MacroProgressRow(title: "protein", grams: viewModel.todayProtein, share: viewModel.todayMacroShare.protein, color: .blue)
            MacroProgressRow(title: "carbs", grams: viewModel.todayCarbs, share: viewModel.todayMacroShare.carbs, color: .green)
            MacroProgressRow(title: "fat", grams: viewModel.todayFat, share: viewModel.todayMacroShare.fat, color: .pink)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("recent_diet_records").font(.headline).padding(.bottom, 8)
            ForEach(viewModel.recentPoints) { point in
                HStack {
                    Text(point.date, format: .dateTime.month().day().weekday(.abbreviated))
                    Spacer()
                    Text(String(format: "%.0f kcal", point.calories))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                if point.id != viewModel.recentPoints.last?.id { Divider() }
            }
        }
    }
}

private struct NutritionPill: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title)).font(.caption).foregroundColor(.secondary)
            Text(String(format: "%.0fg", value)).font(.subheadline.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MacroProgressRow: View {
    let title: String
    let grams: Double
    let share: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(LocalizedStringKey(title))
                Spacer()
                Text(String(format: "%.0fg · %.0f%%", grams, share * 100))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: share)
                .tint(color)
        }
    }
}
