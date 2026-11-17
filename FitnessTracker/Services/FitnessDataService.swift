import Foundation
import SwiftData

@MainActor
enum FitnessDataService {
    static func upsertDailyLog(
        for date: Date,
        profile: UserProfile,
        in context: ModelContext,
        saveChanges: Bool = true
    ) throws -> DailyLog {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return try upsertDailyLogFallback(for: dayStart, profile: profile, in: context, saveChanges: saveChanges)
        }

        var logDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= dayStart && log.date < dayEnd
            },
            sortBy: [SortDescriptor(\DailyLog.date, order: .forward)]
        )
        logDescriptor.fetchLimit = 1
        let existingLog = try context.fetch(logDescriptor).first
        let log = existingLog ?? DailyLog(date: dayStart)

        let exerciseEntries = try context.fetch(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
        ))
        let calorieEntries = try context.fetch(FetchDescriptor<CalorieIntakeEntry>(
            predicate: #Predicate { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
        ))

        let exerciseCalories = exerciseEntries.reduce(0) { $0 + $1.caloriesBurned }
        let calorieIntake = IntakeAggregation.total(calorieEntries)
        let balance = HealthCalculationService.calculateEnergyBalance(
            profile: profile,
            calorieIntake: calorieIntake,
            exerciseCalories: exerciseCalories,
            on: dayStart
        )

        log.date = dayStart
        log.calorieIntake = balance.calorieIntake
        log.exerciseCalories = balance.exerciseCalories
        log.bmr = balance.bmr
        log.tdee = balance.tdee
        log.dailyBalance = balance.dailyBalance

        if existingLog == nil {
            context.insert(log)
        }
        if saveChanges { try context.save() }
        return log
    }

    static func recalculateStoredLogs(for profile: UserProfile, in context: ModelContext) throws {
        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        for log in logs {
            _ = try upsertDailyLog(for: log.date, profile: profile, in: context)
        }
        try context.save()
    }

    static func synchronizeTrackedDays(
        for profile: UserProfile,
        including dates: [Date] = [Date()],
        in context: ModelContext
    ) throws {
        let exercises = try context.fetch(FetchDescriptor<ExerciseEntry>())
        let intakes = try context.fetch(FetchDescriptor<CalorieIntakeEntry>())
        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        let trackedDates = dates + exercises.map(\.date) + intakes.map(\.date) + logs.map(\.date)
        let uniqueDays = Set(trackedDates.map { DateHelpers.startOfDay($0) })

        for day in uniqueDays {
            _ = try upsertDailyLog(for: day, profile: profile, in: context)
        }
    }

    static func saveExercise(
        profile: UserProfile,
        entry: ExerciseEntry?,
        date: Date,
        exerciseType: ExerciseType,
        durationMinutes: Int,
        intensity: ExerciseIntensity,
        caloriesBurned: Double,
        notes: String,
        category: ExerciseCategory? = nil,
        energyUnavailable: Bool = false,
        effortAvailable: Bool = true,
        in context: ModelContext
    ) throws {
        try HealthValidationService.validateExercise(
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned
        )

        let oldDate = entry?.date
        let savedEntry = entry ?? ExerciseEntry(
            date: date,
            exerciseType: exerciseType,
            durationMinutes: durationMinutes,
            intensity: intensity,
            caloriesBurned: caloriesBurned,
            notes: notes
        )
        savedEntry.date = date
        if savedEntry.exerciseType != exerciseType { savedEntry.healthActivityName = "" }
        savedEntry.exerciseType = exerciseType
        savedEntry.durationMinutes = durationMinutes
        savedEntry.intensity = intensity
        savedEntry.caloriesBurned = caloriesBurned
        savedEntry.notes = notes
        savedEntry.trainingCategory = category ?? exerciseType.category
        savedEntry.healthEnergyUnavailable = energyUnavailable
        savedEntry.hasPerceivedEffort = effortAvailable

        if entry == nil {
            context.insert(savedEntry)
        }
        try context.save()
        _ = try upsertDailyLog(for: date, profile: profile, in: context)
        if let oldDate, !DateHelpers.isSameDay(oldDate, date) {
            _ = try upsertDailyLog(for: oldDate, profile: profile, in: context)
        }
    }

    static func deleteExercise(_ entry: ExerciseEntry, profile: UserProfile, in context: ModelContext) throws {
        let date = entry.date
        context.delete(entry)
        try context.save()
        _ = try upsertDailyLog(for: date, profile: profile, in: context)
    }

    static func saveCalorieIntake(
        profile: UserProfile,
        entry: CalorieIntakeEntry?,
        date: Date,
        calories: Double,
        notes: String,
        mealCategory: MealCategory = .dailyTotal,
        in context: ModelContext
    ) throws {
        try HealthValidationService.validateCalorieIntake(calories)

        let oldDate = entry?.date
        let savedEntry = entry ?? CalorieIntakeEntry(date: date, calories: calories, notes: notes)
        savedEntry.date = date
        savedEntry.calories = calories
        savedEntry.notes = notes
        savedEntry.mealCategory = mealCategory

        if entry == nil {
            context.insert(savedEntry)
        }
        try context.save()
        _ = try upsertDailyLog(for: date, profile: profile, in: context)
        if let oldDate, !DateHelpers.isSameDay(oldDate, date) {
            _ = try upsertDailyLog(for: oldDate, profile: profile, in: context)
        }
    }

    static func deleteCalorieIntake(_ entry: CalorieIntakeEntry, profile: UserProfile, in context: ModelContext) throws {
        let date = entry.date
        context.delete(entry)
        try context.save()
        _ = try upsertDailyLog(for: date, profile: profile, in: context)
    }

    static func saveWeight(
        profile: UserProfile,
        entry: WeightEntry?,
        date: Date,
        weightKg: Double,
        in context: ModelContext
    ) throws {
        try HealthValidationService.validateWeight(weightKg)

        let savedEntry = entry ?? WeightEntry(date: date, weightKg: weightKg)
        savedEntry.date = date
        savedEntry.weightKg = weightKg
        if entry == nil {
            context.insert(savedEntry)
        }

        profile.weightKg = try latestWeight(in: context, including: savedEntry).weightKg
        profile.updatedAt = Date()
        try context.save()
        _ = try upsertDailyLog(for: Date(), profile: profile, in: context)
    }

    static func deleteWeight(_ entry: WeightEntry, profile: UserProfile, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.date, order: .reverse)]
        ))
        if let latest = weights.first {
            profile.weightKg = latest.weightKg
        }
        profile.updatedAt = Date()
        try context.save()
        _ = try upsertDailyLog(for: Date(), profile: profile, in: context)
    }

    static func commitProfileChanges(_ profile: UserProfile, draft: ProfileDraft, in context: ModelContext) throws {
        try HealthValidationService.validateProfile(
            dateOfBirth: draft.dateOfBirth,
            heightCm: draft.heightCm,
            weightKg: draft.weightKg,
            bodyFatPercentage: draft.bodyFatPercentage,
            leanBodyMassKg: draft.leanBodyMassKg
        )
        draft.apply(to: profile)
        profile.updatedAt = Date()
        try context.save()
        try recalculateStoredLogs(for: profile, in: context)
    }

    private static func latestWeight(in context: ModelContext, including entry: WeightEntry) throws -> WeightEntry {
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.date, order: .reverse)]
        ))
        return weights.first ?? entry
    }

    private static func upsertDailyLogFallback(
        for date: Date,
        profile: UserProfile,
        in context: ModelContext,
        saveChanges: Bool = true
    ) throws -> DailyLog {
        let log = DailyLog(date: date)
        context.insert(log)
        let balance = HealthCalculationService.calculateEnergyBalance(
            profile: profile,
            calorieIntake: 0,
            exerciseCalories: 0,
            on: date
        )
        log.bmr = balance.bmr
        log.tdee = balance.tdee
        log.dailyBalance = balance.dailyBalance
        if saveChanges { try context.save() }
        return log
    }
}
