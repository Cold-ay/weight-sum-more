import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile
    @State private var draft: ProfileDraft
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var leanMassText = ""
    @State private var errorMessage: String?
    @State private var isShowingSaved = false
    @State private var displayedUsesMetricUnits = true
    @AppStorage("appLanguage") private var language = AppLanguage.system.rawValue

    init(profile: UserProfile) {
        self.profile = profile
        _draft = State(initialValue: ProfileDraft(profile: profile))
    }

    var body: some View {
        VitalityScreen(
            title: "Profile",
            subtitle: "Tune the metrics that power your BMR, TDEE, daily balance, and weekly trend estimates.",
            trailingSystemImage: "person.crop.circle"
        ) {
            VStack(spacing: 14) {
                VitalityCard {
                    Picker("Language", selection: $language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .tint(VitalityTheme.primary)
                }
                HStack(spacing: 12) {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Biological Sex")
                            Picker("Biological sex", selection: $draft.sex) {
                                ForEach(BiologicalSex.allCases) { Text($0.displayName.uppercased()).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .tint(VitalityTheme.primary)
                        }
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Units")
                            Picker("Units", selection: $draft.usesMetricUnits) {
                                Text("KG").tag(true)
                                Text("LB").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .tint(VitalityTheme.primary)
                        }
                    }
                }

                VitalityCard {
                    VStack(alignment: .leading, spacing: 10) {
                        VitalitySectionLabel(text: "Date of Birth")
                        DatePicker("Date of birth", selection: $draft.dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(VitalityTheme.primary)
                    }
                }

                HStack(spacing: 12) {
                    VitalityTextField(title: "Height", unit: draft.usesMetricUnits ? "cm" : "in", text: $heightText, keyboardType: .decimalPad)
                    VitalityTextField(title: "Weight", unit: draft.usesMetricUnits ? "kg" : "lb", text: $weightText, keyboardType: .decimalPad)
                }

                HStack(spacing: 12) {
                    VitalityTextField(title: "Body Fat %", unit: "%", text: $bodyFatText, keyboardType: .decimalPad)
                    VitalityTextField(title: "Lean Mass", unit: "kg", text: $leanMassText, keyboardType: .decimalPad)
                }

                VitalityCard {
                    VStack(alignment: .leading, spacing: 10) {
                        VitalitySectionLabel(text: "Activity Level")
                        Picker("Activity level", selection: $draft.activityLevel) {
                            ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(VitalityTheme.primary)
                    }
                }

                VitalityCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VitalitySectionLabel(text: "Primary Goal")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(FitnessGoal.allCases) { goal in
                                goalButton(goal)
                            }
                        }
                    }
                }

                VitalityCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VitalitySectionLabel(text: "Health Context")
                        Toggle("Pregnant or breastfeeding", isOn: $draft.isPregnantOrBreastfeeding)
                        Toggle("Thyroid/metabolism condition", isOn: $draft.hasMetabolismCondition)
                        Toggle("Medication affects weight/metabolism", isOn: $draft.medicationAffectsWeight)
                        DisclaimerBanner(isCaution: draft.needsHealthDisclaimer)
                    }
                    .tint(VitalityTheme.primary)
                    .foregroundStyle(VitalityTheme.text)
                }

                VitalityPrimaryButton(title: "Save Profile Changes", systemImage: "checkmark") {
                    saveProfile()
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Couldn’t save profile", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(L10n.text(errorMessage ?? "Please check your profile values and try again."))
        }
        .onAppear {
            draft = ProfileDraft(profile: profile)
            syncDisplayFields()
        }
        .onChange(of: draft.usesMetricUnits) { _, isMetric in
            guard displayedUsesMetricUnits != isMetric else { return }
            let wasMetric = displayedUsesMetricUnits
            if let height = Double(heightText) {
                heightText = formatted(wasMetric ? height / 2.54 : height * 2.54)
            }
            if let weight = Double(weightText) {
                weightText = formatted(wasMetric ? UnitConversionService.convertKgToLb(weight) : UnitConversionService.convertLbToKg(weight))
            }
            displayedUsesMetricUnits = isMetric
        }
        .alert("Profile saved", isPresented: $isShowingSaved) {
            Button("OK", role: .cancel) { }
        }
    }

    private func goalButton(_ goal: FitnessGoal) -> some View {
        Button {
            draft.fitnessGoal = goal
        } label: {
            VStack(spacing: 8) {
                Image(systemName: goal.systemImage)
                    .font(.title3.weight(.bold))
                Text(goal.displayName.uppercased())
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(draft.fitnessGoal == goal ? VitalityTheme.primary : VitalityTheme.text)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(draft.fitnessGoal == goal ? VitalityTheme.primary.opacity(0.12) : VitalityTheme.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous)
                    .stroke(draft.fitnessGoal == goal ? VitalityTheme.primary : VitalityTheme.outline)
            )
        }
        .buttonStyle(.plain)
    }

    private func syncDisplayFields() {
        displayedUsesMetricUnits = profile.usesMetricUnits
        if profile.usesMetricUnits {
            heightText = formatted(profile.heightCm)
            weightText = formatted(profile.weightKg)
        } else {
            heightText = formatted(profile.heightCm / 2.54)
            weightText = formatted(UnitConversionService.convertKgToLb(profile.weightKg))
        }
        bodyFatText = profile.bodyFatPercentage.map(formatted) ?? ""
        leanMassText = profile.leanBodyMassKg.map(formatted) ?? ""
    }

    private func saveProfile() {
        guard let displayedHeight = Double(heightText), let displayedWeight = Double(weightText) else {
            errorMessage = "Enter numeric height and weight values."
            return
        }

        do {
            draft.heightCm = draft.usesMetricUnits ? displayedHeight : displayedHeight * 2.54
            draft.weightKg = draft.usesMetricUnits ? displayedWeight : UnitConversionService.convertLbToKg(displayedWeight)
            draft.bodyFatPercentage = try HealthValidationService.optionalMeasurement(bodyFatText, invalidValue: .invalidBodyFat)
            draft.leanBodyMassKg = try HealthValidationService.optionalMeasurement(leanMassText, invalidValue: .invalidLeanBodyMass)
            try FitnessDataService.commitProfileChanges(profile, draft: draft, in: modelContext)
            isShowingSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: value.rounded() == value ? "%.0f" : "%.1f", value)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
