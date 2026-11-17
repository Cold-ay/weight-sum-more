import Foundation
import HealthKit
import SwiftData

struct HealthWorkoutRecord: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let durationSeconds: Double
    let energyKcal: Double?
    let exerciseType: ExerciseType
    let suggestedCategory: ExerciseCategory?
    let activityName: String
    let sourceName: String
    var minutes: Int { max(1, Int((durationSeconds / 60).rounded())) }
}

@MainActor
final class HealthWorkoutService {
    private let store = HKHealthStore()
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestReadAccess() async throws {
        guard Self.isAvailable else { throw HealthImportError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)])
    }

    func workouts(from start: Date, through end: Date) async throws -> [HealthWorkoutRecord] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKWorkout] ?? []) }
            }
            store.execute(query)
        }
        return samples.filter { $0.duration.isFinite && $0.duration > 0 && $0.duration < Double(Int.max) / 60 }.map { workout in
            let mapping = Self.mapping(workout.workoutActivityType)
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            return HealthWorkoutRecord(id: workout.uuid, startDate: workout.startDate, endDate: workout.endDate,
                                       durationSeconds: workout.duration, energyKcal: energy,
                                       exerciseType: mapping.0, suggestedCategory: mapping.1,
                                       activityName: mapping.2, sourceName: workout.sourceRevision.source.name)
        }
    }

    static func mapping(_ type: HKWorkoutActivityType) -> (ExerciseType, ExerciseCategory?, String) {
        switch type {
        case .running: (.running, .cardio, "Running")
        case .walking: (.walking, .cardio, "Walking")
        case .cycling: (.cycling, .cardio, "Cycling")
        case .swimming: (.swimming, .cardio, "Swimming")
        case .traditionalStrengthTraining: (.gym, .strength, "Weight training")
        case .functionalStrengthTraining: (.bodyweight, .strength, "Functional strength training")
        case .yoga: (.yoga, .mindAndBody, "Yoga")
        case .pilates: (.pilates, .mindAndBody, "Pilates")
        case .flexibility: (.stretching, .mindAndBody, "Stretching")
        case .taiChi: (.other, .mindAndBody, "Tai chi")
        case .hiking: (.walking, .cardio, "Hiking")
        case .elliptical: (.other, .cardio, "Elliptical training")
        case .rowing: (.other, .cardio, "Rowing")
        case .highIntensityIntervalTraining: (.other, nil, "Interval training")
        default: (.other, nil, "Health workout")
        }
    }
}

struct HealthImportResult {
    let imported: Int
    let skipped: Int
}

@MainActor
enum WorkoutImportService {
    static func likelyDuplicate(_ record: HealthWorkoutRecord, among entries: [ExerciseEntry]) -> Bool {
        entries.contains {
            abs($0.date.timeIntervalSince(record.startDate)) <= 120
                && abs(Double($0.durationMinutes) * 60 - record.durationSeconds) <= 120
                && ($0.exerciseType == record.exerciseType || $0.exerciseType == .other || record.exerciseType == .other)
        }
    }

    static func importRecords(_ records: [HealthWorkoutRecord], categories: [UUID: ExerciseCategory] = [:],
                              allowPossibleDuplicates: Set<UUID> = [], profile: UserProfile, in context: ModelContext) throws -> HealthImportResult {
        // A separate context makes the entire batch atomic without rolling back unrelated edits.
        let transaction = ModelContext(context.container)
        transaction.autosaveEnabled = false
        var existing = try transaction.fetch(FetchDescriptor<ExerciseEntry>())
        var ids = Set(existing.compactMap(\.healthWorkoutUUID))
        var affectedDays: Set<Date> = []
        var imported = 0
        var skipped = 0
        for record in records {
            guard record.durationSeconds.isFinite, record.durationSeconds > 0, record.durationSeconds < Double(Int.max) / 60,
                  record.startDate.timeIntervalSinceReferenceDate.isFinite, record.endDate.timeIntervalSinceReferenceDate.isFinite,
                  record.endDate >= record.startDate,
                  record.energyKcal.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw HealthImportError.invalidRecord }
            if ids.contains(record.id.uuidString)
                || (likelyDuplicate(record, among: existing) && !allowPossibleDuplicates.contains(record.id)) {
                skipped += 1
                continue
            }
            guard let category = categories[record.id] ?? record.suggestedCategory else { throw HealthImportError.chooseCategory }
            let entry = ExerciseEntry(date: record.startDate, exerciseType: record.exerciseType,
                                      durationMinutes: record.minutes, intensity: .moderate, caloriesBurned: record.energyKcal ?? 0)
            entry.trainingCategory = category
            entry.healthWorkoutUUID = record.id.uuidString
            entry.healthSourceName = record.sourceName
            entry.healthActivityName = record.activityName
            entry.healthEnergyUnavailable = record.energyKcal == nil
            entry.hasPerceivedEffort = false
            transaction.insert(entry)
            existing.append(entry)
            ids.insert(record.id.uuidString)
            affectedDays.insert(DateHelpers.startOfDay(record.startDate))
            imported += 1
        }
        for day in affectedDays {
            _ = try FitnessDataService.upsertDailyLog(for: day, profile: profile, in: transaction, saveChanges: false)
        }
        try transaction.save()
        return HealthImportResult(imported: imported, skipped: skipped)
    }
}

enum HealthImportError: LocalizedError {
    case unavailable, invalidRecord, chooseCategory
    var errorDescription: String? {
        switch self {
        case .unavailable: "Health data is not available on this device.".localized
        case .invalidRecord: "A workout has invalid duration, dates, or energy. No records were imported.".localized
        case .chooseCategory: "Choose a category for each selected workout before importing.".localized
        }
    }
}
