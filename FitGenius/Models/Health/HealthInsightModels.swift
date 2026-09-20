import Foundation
import SwiftData

enum HealthRecoveryStatus: String, Codable, CaseIterable {
    case ready
    case normal
    case low
    case insufficientData

    var localizedName: String {
        switch self {
        case .ready: return "health_status_ready".localized
        case .normal: return "health_status_normal".localized
        case .low: return "health_status_low".localized
        case .insufficientData: return "health_status_insufficient".localized
        }
    }
}

enum HealthTrainingRecommendation: String, Codable, CaseIterable {
    case normal
    case reduceIntensity
    case recoveryDay
    case lightCardioMobility
    case insufficientData

    var localizedName: String {
        switch self {
        case .normal: return "health_recommend_normal".localized
        case .reduceIntensity: return "health_recommend_reduce".localized
        case .recoveryDay: return "health_recommend_recovery".localized
        case .lightCardioMobility: return "health_recommend_light".localized
        case .insufficientData: return "health_recommend_insufficient".localized
        }
    }
}

struct HealthInsightReason: Codable, Hashable {
    var title: String
    var detail: String
}

struct HealthDailySummaryDTO: Codable, Hashable {
    var date: Date
    var steps: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var standHours: Double?
    var workoutMinutes: Double?
    var averageHeartRate: Double?
    var restingHeartRate: Double?
    var hrvSDNN: Double?
    var sleepMinutes: Double?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var coreSleepMinutes: Double?
    var awakeMinutes: Double?
    var oxygenSaturationPercent: Double?
    var respiratoryRate: Double?
    var wristTemperatureCelsius: Double?
    var vo2Max: Double?
    var bodyMassKg: Double?
    var bodyFatPercent: Double?
    var bmi: Double?
    var waistCm: Double?
}

@Model
final class HealthDailySummary {
    var date: Date
    var steps: Double
    var activeEnergyKcal: Double
    var exerciseMinutes: Double
    var standHours: Double
    var workoutMinutes: Double
    var averageHeartRate: Double
    var restingHeartRate: Double
    var hrvSDNN: Double
    var sleepMinutes: Double
    var deepSleepMinutes: Double
    var remSleepMinutes: Double
    var coreSleepMinutes: Double
    var awakeMinutes: Double
    var oxygenSaturationPercent: Double
    var respiratoryRate: Double
    var wristTemperatureCelsius: Double
    var vo2Max: Double
    var bodyMassKg: Double
    var bodyFatPercent: Double
    var bmi: Double
    var waistCm: Double

    init(dto: HealthDailySummaryDTO) {
        self.date = Calendar.current.startOfDay(for: dto.date)
        self.steps = dto.steps ?? 0
        self.activeEnergyKcal = dto.activeEnergyKcal ?? 0
        self.exerciseMinutes = dto.exerciseMinutes ?? 0
        self.standHours = dto.standHours ?? 0
        self.workoutMinutes = dto.workoutMinutes ?? 0
        self.averageHeartRate = dto.averageHeartRate ?? 0
        self.restingHeartRate = dto.restingHeartRate ?? 0
        self.hrvSDNN = dto.hrvSDNN ?? 0
        self.sleepMinutes = dto.sleepMinutes ?? 0
        self.deepSleepMinutes = dto.deepSleepMinutes ?? 0
        self.remSleepMinutes = dto.remSleepMinutes ?? 0
        self.coreSleepMinutes = dto.coreSleepMinutes ?? 0
        self.awakeMinutes = dto.awakeMinutes ?? 0
        self.oxygenSaturationPercent = dto.oxygenSaturationPercent ?? 0
        self.respiratoryRate = dto.respiratoryRate ?? 0
        self.wristTemperatureCelsius = dto.wristTemperatureCelsius ?? 0
        self.vo2Max = dto.vo2Max ?? 0
        self.bodyMassKg = dto.bodyMassKg ?? 0
        self.bodyFatPercent = dto.bodyFatPercent ?? 0
        self.bmi = dto.bmi ?? 0
        self.waistCm = dto.waistCm ?? 0
    }

    var dto: HealthDailySummaryDTO {
        HealthDailySummaryDTO(
            date: date,
            steps: optional(steps),
            activeEnergyKcal: optional(activeEnergyKcal),
            exerciseMinutes: optional(exerciseMinutes),
            standHours: optional(standHours),
            workoutMinutes: optional(workoutMinutes),
            averageHeartRate: optional(averageHeartRate),
            restingHeartRate: optional(restingHeartRate),
            hrvSDNN: optional(hrvSDNN),
            sleepMinutes: optional(sleepMinutes),
            deepSleepMinutes: optional(deepSleepMinutes),
            remSleepMinutes: optional(remSleepMinutes),
            coreSleepMinutes: optional(coreSleepMinutes),
            awakeMinutes: optional(awakeMinutes),
            oxygenSaturationPercent: optional(oxygenSaturationPercent),
            respiratoryRate: optional(respiratoryRate),
            wristTemperatureCelsius: optional(wristTemperatureCelsius),
            vo2Max: optional(vo2Max),
            bodyMassKg: optional(bodyMassKg),
            bodyFatPercent: optional(bodyFatPercent),
            bmi: optional(bmi),
            waistCm: optional(waistCm)
        )
    }

    private func optional(_ value: Double) -> Double? {
        value > 0 ? value : nil
    }
}

@Model
final class DailyReadinessReportRecord {
    var date: Date
    var energyScore: Int
    var sleepRecoveryPercent: Int
    var dataCoveragePercent: Int = 0
    var statusRaw: String
    var recommendationRaw: String
    var summary: String
    var reasonsJSON: String
    var generatedAt: Date

    init(
        date: Date,
        energyScore: Int,
        sleepRecoveryPercent: Int,
        dataCoveragePercent: Int = 0,
        status: HealthRecoveryStatus,
        recommendation: HealthTrainingRecommendation,
        summary: String,
        reasons: [HealthInsightReason],
        generatedAt: Date = Date()
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.energyScore = energyScore
        self.sleepRecoveryPercent = sleepRecoveryPercent
        self.dataCoveragePercent = dataCoveragePercent
        self.statusRaw = status.rawValue
        self.recommendationRaw = recommendation.rawValue
        self.summary = summary
        self.reasonsJSON = (try? String(data: JSONEncoder().encode(reasons), encoding: .utf8)) ?? "[]"
        self.generatedAt = generatedAt
    }

    var status: HealthRecoveryStatus {
        HealthRecoveryStatus(rawValue: statusRaw) ?? .insufficientData
    }

    var recommendation: HealthTrainingRecommendation {
        HealthTrainingRecommendation(rawValue: recommendationRaw) ?? .insufficientData
    }

    var reasons: [HealthInsightReason] {
        guard let data = reasonsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([HealthInsightReason].self, from: data) else {
            return []
        }
        return decoded
    }
}

@Model
final class WeeklyHealthReportRecord {
    var weekStart: Date
    var weekEnd: Date
    var energyScore: Int
    var trainingExecutionPercent: Int
    var summary: String
    var nextWeekAdvice: String
    var reasonsJSON: String
    var generatedAt: Date

    init(
        weekStart: Date,
        weekEnd: Date,
        energyScore: Int,
        trainingExecutionPercent: Int,
        summary: String,
        nextWeekAdvice: String,
        reasons: [HealthInsightReason],
        generatedAt: Date = Date()
    ) {
        self.weekStart = Calendar.current.startOfDay(for: weekStart)
        self.weekEnd = Calendar.current.startOfDay(for: weekEnd)
        self.energyScore = energyScore
        self.trainingExecutionPercent = trainingExecutionPercent
        self.summary = summary
        self.nextWeekAdvice = nextWeekAdvice
        self.reasonsJSON = (try? String(data: JSONEncoder().encode(reasons), encoding: .utf8)) ?? "[]"
        self.generatedAt = generatedAt
    }

    var reasons: [HealthInsightReason] {
        guard let data = reasonsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([HealthInsightReason].self, from: data) else {
            return []
        }
        return decoded
    }
}

@Model
final class HealthInsightPreference {
    var aiHealthContextEnabled: Bool
    var dailyReportEnabled: Bool
    var weeklyReportEnabled: Bool
    var advancedVitalsEnabled: Bool
    var bodyMetricsEnabled: Bool
    var lastRefreshDate: Date?

    init(
        aiHealthContextEnabled: Bool = false,
        dailyReportEnabled: Bool = true,
        weeklyReportEnabled: Bool = true,
        advancedVitalsEnabled: Bool = false,
        bodyMetricsEnabled: Bool = false,
        lastRefreshDate: Date? = nil
    ) {
        self.aiHealthContextEnabled = aiHealthContextEnabled
        self.dailyReportEnabled = dailyReportEnabled
        self.weeklyReportEnabled = weeklyReportEnabled
        self.advancedVitalsEnabled = advancedVitalsEnabled
        self.bodyMetricsEnabled = bodyMetricsEnabled
        self.lastRefreshDate = lastRefreshDate
    }
}
