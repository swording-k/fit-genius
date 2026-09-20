import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RecoveryInsightEngineTests {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29))!
        let baseline = (1...7).map { offset in
            HealthDailySummaryDTO(
                date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                steps: 8500,
                activeEnergyKcal: 520,
                exerciseMinutes: 45,
                standHours: 10,
                workoutMinutes: 50,
                averageHeartRate: 92,
                restingHeartRate: 58,
                hrvSDNN: 55,
                sleepMinutes: 455
            )
        }

        let poorToday = HealthDailySummaryDTO(
            date: today,
            steps: 3000,
            activeEnergyKcal: 160,
            exerciseMinutes: 8,
            standHours: 5,
            workoutMinutes: 0,
            averageHeartRate: 95,
            restingHeartRate: 68,
            hrvSDNN: 32,
            sleepMinutes: 260
        )
        let poor = RecoveryInsightEngine().buildDailyReport(
            input: DailyReadinessInput(
                summaries: baseline + [poorToday],
                trainingVolumeLast7Days: 90_000,
                completedExercisesLast7Days: 30,
                proteinAverage: 70,
                proteinTarget: 130,
                isTrainingDay: true
            ),
            date: today
        )
        require(poor.energyScore < 62, "poor sleep plus high training load should lower readiness")
        require(poor.recommendation == .recoveryDay || poor.recommendation == .reduceIntensity, "poor recovery should not recommend full training")
        require(!poor.reasons.isEmpty, "daily report should expose evidence")
        require(poor.reasons.count >= 4, "daily report should expose sleep, recovery, training load, and nutrition evidence when available")

        let goodToday = HealthDailySummaryDTO(
            date: today,
            steps: 9000,
            activeEnergyKcal: 480,
            exerciseMinutes: 40,
            standHours: 10,
            workoutMinutes: 0,
            averageHeartRate: 85,
            restingHeartRate: 56,
            hrvSDNN: 62,
            sleepMinutes: 500
        )
        let good = RecoveryInsightEngine().buildDailyReport(
            input: DailyReadinessInput(
                summaries: baseline + [goodToday],
                trainingVolumeLast7Days: 28_000,
                completedExercisesLast7Days: 12,
                proteinAverage: 135,
                proteinTarget: 130,
                isTrainingDay: true
            ),
            date: today
        )
        require(good.energyScore >= 78, "good recovery signals should produce a high readiness score")
        require(good.recommendation == .normal, "good recovery should allow planned training")

        let sleepOnly = RecoveryInsightEngine().buildDailyReport(
            input: DailyReadinessInput(
                summaries: [HealthDailySummaryDTO(
                    date: today,
                    steps: nil,
                    activeEnergyKcal: nil,
                    exerciseMinutes: nil,
                    standHours: nil,
                    workoutMinutes: nil,
                    averageHeartRate: nil,
                    restingHeartRate: nil,
                    hrvSDNN: nil,
                    sleepMinutes: 480
                )],
                trainingVolumeLast7Days: 0,
                completedExercisesLast7Days: 0,
                proteinAverage: 0,
                proteinTarget: 130,
                isTrainingDay: true
            ),
            date: today
        )
        require(sleepOnly.status == .insufficientData, "sleep alone must not claim a confident readiness state")
        require(sleepOnly.recommendation == .insufficientData, "sleep alone must not prescribe a training intensity")
        require(sleepOnly.dataCoveragePercent == 35, "sleep-only reports must disclose their 35% data coverage")
        require(good.dataCoveragePercent == 100, "reports with every scoring signal must disclose full coverage")

        let missingSleep = RecoveryInsightEngine().buildDailyReport(
            input: DailyReadinessInput(
                summaries: [HealthDailySummaryDTO(
                    date: today,
                    steps: nil,
                    activeEnergyKcal: nil,
                    exerciseMinutes: nil,
                    standHours: nil,
                    workoutMinutes: nil,
                    averageHeartRate: nil,
                    restingHeartRate: 60,
                    hrvSDNN: 48,
                    sleepMinutes: nil
                )],
                trainingVolumeLast7Days: 0,
                completedExercisesLast7Days: 0,
                proteinAverage: 0,
                proteinTarget: 130,
                isTrainingDay: true
            ),
            date: today
        )
        require(missingSleep.sleepRecoveryPercent == -1, "missing sleep must be represented as unavailable, never as a default recovery percentage")

        let weekly = RecoveryInsightEngine().buildWeeklyReport(
            input: WeeklyHealthInput(
                summaries: baseline + [goodToday],
                plannedTrainingDays: 4,
                completedTrainingDays: 3,
                completedExercises: 15,
                trainingVolume: 36_000,
                averageCalories: 2400,
                averageProtein: 135,
                averageCarbs: 280,
                averageFat: 70,
                proteinTarget: 130
            ),
            weekStart: calendar.date(byAdding: .day, value: -6, to: today)!,
            weekEnd: today
        )
        require(weekly.reasons.count >= 4, "weekly report should expose training execution, sleep, HRV, and nutrition evidence")

        print("recovery-insight-engine-tests: PASS")
    }
}
