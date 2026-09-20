import SwiftUI

struct HealthReadinessCard: View {
    @ObservedObject var viewModel: HealthInsightViewModel
    let profile: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("health_today_status", systemImage: "heart.text.square.fill")
                        .font(.headline)
                    Text("health_non_medical_notice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                }
            }

            if !viewModel.isHealthAvailable {
                unavailableContent
            } else if let report = viewModel.dailyReport {
                reportContent(report)
            } else {
                connectContent
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .task {
            await viewModel.refreshIfNeeded(profile: profile)
        }
    }

    private var connectContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("health_connect_description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.requestAndRefresh(profile: profile) }
            } label: {
                Label("health_connect_action", systemImage: "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var unavailableContent: some View {
        Text("health_unavailable")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func reportContent(_ report: DailyReadinessReportRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.14), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.energyScore) / 100)
                        .stroke(scoreColor(report.energyScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(report.energyScore)")
                            .font(.title.bold())
                        Text("health_score_suffix")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 8) {
                    Text(report.status.localizedName)
                        .font(.title3.bold())
                    Text(report.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(report.recommendation.localizedName, systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scoreColor(report.energyScore))
                }
            }

                HStack(spacing: 10) {
                    metricPill(title: "health_sleep_recovery", value: sleepRecoveryValue(report))
                    metricPill(title: "health_data_coverage", value: "\(report.dataCoveragePercent)%")
                }

                Text("health_data_coverage_detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            ForEach(report.reasons, id: \.self) { reason in
                VStack(alignment: .leading, spacing: 3) {
                    Text(reason.title)
                        .font(.caption.weight(.semibold))
                    Text(reason.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await viewModel.requestAndRefresh(profile: profile) }
            } label: {
                Label("health_refresh_report", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            NavigationLink {
                HealthReportDetailView(viewModel: viewModel, profile: profile)
            } label: {
                Label("health_view_full_report", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func metricPill(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 78 { return .green }
        if score >= 58 { return .blue }
        return .orange
    }
}

struct HealthReportDetailView: View {
    @ObservedObject var viewModel: HealthInsightViewModel
    let profile: UserProfile?
    @State private var selection = 0

    private var todaySummary: HealthDailySummaryDTO? {
        viewModel.recentSummaries.last
    }

    private var previousSummaries: [HealthDailySummaryDTO] {
        Array(viewModel.recentSummaries.dropLast().suffix(14))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("health_report_scope", selection: $selection) {
                    Text("health_report_today_tab").tag(0)
                    Text("health_report_week_tab").tag(1)
                }
                .pickerStyle(.segmented)

                if selection == 0 {
                    DailyHealthReportSection(
                        report: viewModel.dailyReport,
                        today: todaySummary,
                        baseline: previousSummaries,
                        isLoading: viewModel.isLoading,
                        refresh: { Task { await viewModel.requestAndRefresh(profile: profile) } }
                    )
                } else {
                    WeeklyHealthReportSection(
                        report: viewModel.weeklyReport,
                        summaries: viewModel.recentSummaries.suffix(7),
                        refresh: { Task { await viewModel.requestAndRefresh(profile: profile) } }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("health_body_report_title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshIfNeeded(profile: profile)
        }
    }
}

private struct DailyHealthReportSection: View {
    let report: DailyReadinessReportRecord?
    let today: HealthDailySummaryDTO?
    let baseline: [HealthDailySummaryDTO]
    let isLoading: Bool
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let report {
                HealthScoreHeader(report: report)

                Text("health_daily_explanation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HealthMetricGrid(items: dailyItems(report: report))

                HealthEvidenceSection(reasons: report.reasons)

                if hasAdvancedWatchData {
                    HealthWatchSignalSection(today: today)
                } else {
                    HealthDataHintSection()
                }
            } else {
                ContentUnavailableView(
                    "health_report_not_generated",
                    systemImage: "heart.text.square",
                    description: Text("health_connect_description")
                )
            }

            Button(action: refresh) {
                Label(isLoading ? "health_report_refreshing" : "health_refresh_report", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }

    private var hasAdvancedWatchData: Bool {
        guard let today else { return false }
        return (today.hrvSDNN ?? 0) > 0
            || (today.deepSleepMinutes ?? 0) > 0
            || (today.remSleepMinutes ?? 0) > 0
            || (today.oxygenSaturationPercent ?? 0) > 0
            || (today.vo2Max ?? 0) > 0
            || (today.wristTemperatureCelsius ?? 0) > 0
    }

    private func dailyItems(report: DailyReadinessReportRecord) -> [HealthReportMetricItem] {
        [
            HealthReportMetricItem(
                title: "health_report_sleep",
                value: formatMinutes(today?.sleepMinutes),
                detail: baselineDetail(today?.sleepMinutes, baseline.compactMap(\.sleepMinutes), unit: "health_unit_sleep"),
                systemImage: "bed.double.fill",
                color: .indigo
            ),
            HealthReportMetricItem(
                title: "health_report_hrv",
                value: formatNumber(today?.hrvSDNN, suffix: " ms"),
                detail: baselineDetail(today?.hrvSDNN, baseline.compactMap(\.hrvSDNN), unit: "health_unit_hrv"),
                systemImage: "waveform.path.ecg",
                color: .pink
            ),
            HealthReportMetricItem(
                title: "health_report_resting_hr",
                value: formatNumber(today?.restingHeartRate, suffix: " bpm"),
                detail: baselineDetail(today?.restingHeartRate, baseline.compactMap(\.restingHeartRate), unit: "health_unit_heart_rate"),
                systemImage: "heart.fill",
                color: .red
            ),
            HealthReportMetricItem(
                title: "health_sleep_recovery",
                value: sleepRecoveryValue(report),
                detail: sleepRecoveryDetail(report),
                systemImage: "moon.zzz.fill",
                color: .blue
            ),
            HealthReportMetricItem(
                title: "health_report_activity",
                value: formatSteps(today?.steps),
                detail: formatActiveEnergy(today?.activeEnergyKcal, exercise: today?.exerciseMinutes),
                systemImage: "figure.walk",
                color: .green
            ),
            HealthReportMetricItem(
                title: "health_report_training_advice",
                value: report.recommendation.localizedName,
                detail: report.status.localizedName,
                systemImage: "figure.strengthtraining.traditional",
                color: .orange
            )
        ]
    }
}

private func sleepRecoveryValue(_ report: DailyReadinessReportRecord) -> String {
    report.sleepRecoveryPercent >= 0
        ? "\(report.sleepRecoveryPercent)%"
        : "health_data_unavailable".localized
}

private func sleepRecoveryDetail(_ report: DailyReadinessReportRecord) -> String {
    report.sleepRecoveryPercent >= 0
        ? "health_report_sleep_recovery_detail".localized
        : "health_report_sleep_recovery_unavailable".localized
}

private struct WeeklyHealthReportSection: View {
    let report: WeeklyHealthReportRecord?
    let summaries: ArraySlice<HealthDailySummaryDTO>
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let report {
                VStack(alignment: .leading, spacing: 8) {
                    Text("health_weekly_report_title")
                        .font(.title2.bold())
                    Text(report.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(report.nextWeekAdvice)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                HealthMetricGrid(items: [
                    HealthReportMetricItem(title: "health_reason_training_execution", value: "\(report.trainingExecutionPercent)%", detail: "health_weekly_training_detail".localized, systemImage: "checkmark.circle.fill", color: .green),
                    HealthReportMetricItem(title: "health_score_suffix", value: "\(report.energyScore)", detail: "health_weekly_score_detail".localized, systemImage: "bolt.heart.fill", color: .blue),
                    HealthReportMetricItem(title: "health_report_sleep", value: formatMinutes(average(summaries.compactMap(\.sleepMinutes))), detail: "health_weekly_sleep_detail".localized, systemImage: "bed.double.fill", color: .indigo),
                    HealthReportMetricItem(title: "health_report_hrv", value: formatNumber(average(summaries.compactMap(\.hrvSDNN)), suffix: " ms"), detail: "health_weekly_hrv_detail".localized, systemImage: "waveform.path.ecg", color: .pink)
                ])

                HealthEvidenceSection(reasons: report.reasons)
                HealthTrendStrip(summaries: Array(summaries))
            } else {
                ContentUnavailableView(
                    "health_weekly_report_empty",
                    systemImage: "calendar.badge.clock",
                    description: Text("health_weekly_report_empty_detail")
                )
            }

            Button(action: refresh) {
                Label("health_refresh_report", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct HealthScoreHeader: View {
    let report: DailyReadinessReportRecord

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.blue.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(report.energyScore) / 100)
                    .stroke(scoreColor(report.energyScore), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(report.energyScore)")
                        .font(.system(size: 34, weight: .bold))
                    Text("health_score_suffix")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Text(report.status.localizedName)
                    .font(.title2.bold())
                Text(report.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(report.recommendation.localizedName, systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor(report.energyScore))
                Text("health_data_coverage_value".localized(with: report.dataCoveragePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

private struct HealthReportMetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color
}

private struct HealthMetricGrid: View {
    let items: [HealthReportMetricItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: item.systemImage)
                        .font(.headline)
                        .foregroundStyle(item.color)
                    Text(LocalizedStringKey(item.title))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
}

private struct HealthEvidenceSection: View {
    let reasons: [HealthInsightReason]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("health_report_evidence_title")
                .font(.headline)
            ForEach(reasons, id: \.self) { reason in
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(.subheadline.weight(.semibold))
                    Text(reason.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

private struct HealthWatchSignalSection: View {
    let today: HealthDailySummaryDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("health_watch_signals_title", systemImage: "applewatch")
                .font(.headline)
            Text("health_watch_signals_detail")
                .font(.caption)
                .foregroundStyle(.secondary)
            HealthMetricGrid(items: [
                HealthReportMetricItem(title: "health_report_deep_sleep", value: formatMinutes(today?.deepSleepMinutes), detail: "health_watch_sleep_stage_detail".localized, systemImage: "moon.fill", color: .indigo),
                HealthReportMetricItem(title: "health_report_rem_sleep", value: formatMinutes(today?.remSleepMinutes), detail: "health_watch_sleep_stage_detail".localized, systemImage: "brain.head.profile", color: .purple),
                HealthReportMetricItem(title: "health_report_oxygen", value: formatPercent(today?.oxygenSaturationPercent), detail: "health_watch_optional_detail".localized, systemImage: "lungs.fill", color: .cyan),
                HealthReportMetricItem(title: "health_report_vo2", value: formatNumber(today?.vo2Max, suffix: ""), detail: "health_watch_optional_detail".localized, systemImage: "figure.run", color: .green)
            ])
        }
    }
}

private struct HealthDataHintSection: View {
    var body: some View {
        Label("health_watch_data_hint", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }
}

private struct HealthTrendStrip: View {
    let summaries: [HealthDailySummaryDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("health_recent_trends")
                .font(.headline)
            ForEach(summaries.suffix(7), id: \.date) { summary in
                HStack {
                    Text(summary.date, format: .dateTime.month().day())
                        .font(.caption)
                        .frame(width: 48, alignment: .leading)
                    trendValue(title: "health_report_sleep", value: formatMinutes(summary.sleepMinutes))
                    trendValue(title: "health_report_hrv", value: formatNumber(summary.hrvSDNN, suffix: " ms"))
                    trendValue(title: "health_report_activity", value: formatSteps(summary.steps))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func trendValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func scoreColor(_ score: Int) -> Color {
    if score >= 78 { return .green }
    if score >= 58 { return .blue }
    return .orange
}

private func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

private func formatMinutes(_ minutes: Double?) -> String {
    guard let minutes, minutes > 0 else { return "health_data_unavailable".localized }
    let hours = Int(minutes / 60)
    let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
    if hours > 0 {
        return "\(hours)h \(mins)m"
    }
    return "\(mins)m"
}

private func formatNumber(_ value: Double?, suffix: String) -> String {
    guard let value, value > 0 else { return "health_data_unavailable".localized }
    return "\(Int(value.rounded()))\(suffix)"
}

private func formatSteps(_ value: Double?) -> String {
    guard let value, value > 0 else { return "health_data_unavailable".localized }
    return "\(Int(value.rounded()))"
}

private func formatPercent(_ value: Double?) -> String {
    guard let value, value > 0 else { return "health_data_unavailable".localized }
    let normalized = value <= 1 ? value * 100 : value
    return "\(Int(normalized.rounded()))%"
}

private func formatActiveEnergy(_ energy: Double?, exercise: Double?) -> String {
    let energyText = formatNumber(energy, suffix: " kcal")
    let exerciseText = formatMinutes(exercise)
    return "\(energyText) / \(exerciseText)"
}

private func baselineDetail(_ today: Double?, _ baseline: [Double], unit: String) -> String {
    guard let today, today > 0, !baseline.isEmpty, let averageValue = average(baseline) else {
        return "health_report_baseline_missing".localized
    }
    let delta = today - averageValue
    if abs(delta) < max(1, averageValue * 0.03) {
        return "health_report_near_baseline".localized
    }
    return delta > 0 ? "health_report_above_baseline".localized : "health_report_below_baseline".localized
}
