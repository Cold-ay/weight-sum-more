import SwiftUI
import SwiftData

struct MonthlyGoalCard: View {
    let goal: MonthlyGoal?
    let exercises: [ExerciseEntry]
    let date: Date
    let editAction: () -> Void

    var body: some View {
        if let goal {
            let progress = MonthlyGoalService.progress(for: goal, exercises: exercises, asOf: date)

            Button(action: editAction) {
                VitalityCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VitalitySectionLabel(text: "This Month's Target")
                            Spacer()
                            Image(systemName: goal.type.systemImage)
                                .foregroundStyle(statusColor(progress))
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(progress.currentValue)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(statusColor(progress))
                            Text(L10n.format("of %ld %@", progress.targetValue, goal.type.unitName))
                                .font(.headline)
                                .foregroundStyle(VitalityTheme.text)
                        }

                        ProgressView(value: progress.fractionComplete)
                            .tint(statusColor(progress))
                            .scaleEffect(x: 1, y: 1.7, anchor: .center)

                        HStack(alignment: .top) {
                            Label(L10n.text(statusTitle(progress)), systemImage: statusIcon(progress))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(statusColor(progress))
                            Spacer()
                            Text(daysText(progress.daysRemaining))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VitalityTheme.textMuted)
                        }

                        Text(guidanceText(goal: goal, progress: progress))
                            .font(.footnote)
                            .foregroundStyle(VitalityTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit this month's target")
        } else {
            Button(action: editAction) {
                VitalityCard {
                    HStack(spacing: 14) {
                        Image(systemName: "target")
                            .font(.title2.bold())
                            .foregroundStyle(VitalityTheme.primary)
                            .frame(width: 46, height: 46)
                            .background(VitalityTheme.primary.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            VitalitySectionLabel(text: "This Month's Target")
                            Text(L10n.format("Set a goal for %@", date.formatted(.dateTime.month(.wide).locale(L10n.locale))))
                                .font(.headline)
                                .foregroundStyle(VitalityTheme.text)
                            Text("Turn your workout history into a clear monthly finish line.")
                                .font(.footnote)
                                .foregroundStyle(VitalityTheme.textMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(VitalityTheme.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func statusTitle(_ progress: MonthlyGoalProgress) -> String {
        if progress.isComplete { return "Target complete" }
        return progress.isOnPace ? "On pace" : "A little behind"
    }

    private func statusIcon(_ progress: MonthlyGoalProgress) -> String {
        if progress.isComplete { return "checkmark.seal.fill" }
        return progress.isOnPace ? "arrow.up.right.circle.fill" : "arrow.forward.circle.fill"
    }

    private func statusColor(_ progress: MonthlyGoalProgress) -> Color {
        if progress.isComplete { return VitalityTheme.success }
        return progress.isOnPace ? VitalityTheme.primary : VitalityTheme.warning
    }

    private func daysText(_ days: Int) -> String {
        L10n.format("%ld days remaining", days)
    }

    private func guidanceText(goal: MonthlyGoal, progress: MonthlyGoalProgress) -> String {
        if progress.isComplete {
            return "You reached your target. Any extra activity is a bonus.".localized
        }

        let pace = progress.requiredDailyPace
        switch goal.type {
        case .workouts:
            if pace < 1, pace > 0 {
                let interval = max(Int((1 / pace).rounded(.down)), 1)
                return L10n.format("Complete about one workout every %ld days to finish.", interval)
            }
            return L10n.format("Average %.1f workouts per day to finish.", pace)
        case .activeMinutes:
            return L10n.format("Average %ld active minutes per day to finish.", Int(ceil(pace)))
        }
    }
}

struct MonthlyGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: MonthlyGoal?
    let month: Date

    @State private var type: MonthlyGoalType = .workouts
    @State private var targetValue = 12
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VitalityScreen(
                title: goal == nil ? "Set Monthly Target" : "Edit Monthly Target",
                subtitle: "Choose one clear result to work toward this month. Progress updates from your exercise log."
            ) {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "Goal Type")
                            Picker("Goal type", selection: $type) {
                                ForEach(MonthlyGoalType.allCases) { goalType in
                                    Text(goalType.displayName).tag(goalType)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: type) { oldValue, newValue in
                                guard oldValue != newValue else { return }
                                targetValue = newValue == .workouts ? 12 : 600
                            }
                        }
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 14) {
                            VitalitySectionLabel(text: L10n.format("%@ target", month.formatted(.dateTime.month(.wide).locale(L10n.locale))))
                            HStack {
                                Button {
                                    targetValue = max(targetValue - stepAmount, minimumTarget)
                                } label: {
                                    Image(systemName: "minus")
                                }
                                .buttonStyle(GoalAdjustButtonStyle())

                                Spacer()
                                VStack(spacing: 4) {
                                    Text("\(targetValue)")
                                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                                        .foregroundStyle(VitalityTheme.primary)
                                    Text(type.unitName.uppercased())
                                        .font(.caption.weight(.black))
                                        .tracking(1)
                                        .foregroundStyle(VitalityTheme.textMuted)
                                }
                                Spacer()

                                Button {
                                    targetValue = min(targetValue + stepAmount, maximumTarget)
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(GoalAdjustButtonStyle())
                            }
                        }
                    }

                    VitalityPrimaryButton(
                        title: goal == nil ? "Start This Target" : "Save Target",
                        systemImage: "target"
                    ) {
                        save()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: loadGoal)
            .alert("Couldn’t save target", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please try again."))
            }
        }
    }

    private var stepAmount: Int { type == .workouts ? 1 : 30 }
    private var minimumTarget: Int { type == .workouts ? 1 : 30 }
    private var maximumTarget: Int { type == .workouts ? 100 : 10_000 }

    private func loadGoal() {
        guard let goal else { return }
        type = goal.type
        targetValue = goal.targetValue
    }

    private func save() {
        let monthStart = MonthlyGoalService.monthInterval(containing: month).start
        let savedGoal = goal ?? MonthlyGoal(month: monthStart, type: type, targetValue: targetValue)
        savedGoal.month = monthStart
        savedGoal.type = type
        savedGoal.targetValue = targetValue
        savedGoal.updatedAt = Date()

        if goal == nil {
            modelContext.insert(savedGoal)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

private struct GoalAdjustButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundStyle(VitalityTheme.primary)
            .frame(width: 48, height: 48)
            .background(VitalityTheme.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous)
                    .stroke(VitalityTheme.outline)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
