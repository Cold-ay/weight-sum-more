import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var sex: BiologicalSex = .male
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var usesMetricUnits = true
    @State private var heightCm = "175"
    @State private var weightKg = "75"
    @State private var heightFeet = "5"
    @State private var heightInches = "9"
    @State private var weightLb = "165"
    @State private var bodyFatText = ""
    @State private var leanMassText = ""
    @State private var activityLevel: ActivityLevel = .lightlyActive
    @State private var fitnessGoal: FitnessGoal = .maintainWeight
    @State private var isPregnantOrBreastfeeding = false
    @State private var hasMetabolismCondition = false
    @State private var medicationAffectsWeight = false
    @State private var errorMessage: String?
    @AppStorage("appLanguage") private var language = AppLanguage.system.rawValue

    var body: some View {
        NavigationStack {
            VitalityScreen(
                title: "Create Profile",
                subtitle: "Let's personalize your experience. These metrics calculate your Basal Metabolic Rate and tailor your fitness goals.",
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
                                Picker("Biological sex", selection: $sex) {
                                    ForEach(BiologicalSex.allCases) { Text($0.displayName.uppercased()).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .tint(VitalityTheme.primary)
                            }
                        }

                        VitalityCard {
                            VStack(alignment: .leading, spacing: 10) {
                                VitalitySectionLabel(text: "Units")
                                Picker("Units", selection: $usesMetricUnits) {
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
                            DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(VitalityTheme.primary)
                        }
                    }

                    unitFields

                    HStack(spacing: 12) {
                        VitalityTextField(title: "Body Fat % (Optional)", unit: "%", text: $bodyFatText, keyboardType: .decimalPad)
                        VitalityTextField(title: "Lean Mass (Optional)", unit: usesMetricUnits ? "kg" : "kg", text: $leanMassText, keyboardType: .decimalPad)
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Activity Level")
                            Picker("Activity level", selection: $activityLevel) {
                                ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(VitalityTheme.primary)
                        }
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "What's your primary goal?")
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
                            Toggle("Pregnant or breastfeeding", isOn: $isPregnantOrBreastfeeding)
                            Toggle("Thyroid/metabolism condition", isOn: $hasMetabolismCondition)
                            Toggle("Medication affects weight/metabolism", isOn: $medicationAffectsWeight)
                            DisclaimerBanner(isCaution: isPregnantOrBreastfeeding || hasMetabolismCondition || medicationAffectsWeight)
                        }
                        .tint(VitalityTheme.primary)
                        .foregroundStyle(VitalityTheme.text)
                    }

                    VitalityPrimaryButton(title: "Calculate My BMR", systemImage: "function") {
                        saveProfile()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onChange(of: usesMetricUnits) { wasMetric, _ in
                if wasMetric {
                    if let cm = Double(heightCm), (0...10_000).contains(cm) {
                        let totalInches = cm / 2.54
                        let feet = floor(totalInches / 12)
                        heightFeet = String(Int(feet))
                        heightInches = String(format: "%.1f", totalInches - feet * 12)
                    }
                    if let kg = Double(weightKg) {
                        weightLb = String(format: "%.1f", UnitConversionService.convertKgToLb(kg))
                    }
                } else {
                    if let feet = Double(heightFeet), let inches = Double(heightInches) {
                        heightCm = String(format: "%.1f", UnitConversionService.convertFeetInchesToCm(feet: feet, inches: inches))
                    }
                    if let lb = Double(weightLb) {
                        weightKg = String(format: "%.1f", UnitConversionService.convertLbToKg(lb))
                    }
                }
            }
            .alert("Couldn’t create profile", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check your profile values and try again."))
            }
        }
    }

    @ViewBuilder
    private var unitFields: some View {
        if usesMetricUnits {
            HStack(spacing: 12) {
                VitalityTextField(title: "Height", unit: "cm", text: $heightCm, keyboardType: .decimalPad)
                VitalityTextField(title: "Current Weight", unit: "kg", text: $weightKg, keyboardType: .decimalPad)
            }
        } else {
            HStack(spacing: 12) {
                VitalityTextField(title: "Feet", unit: "ft", text: $heightFeet, keyboardType: .numberPad)
                VitalityTextField(title: "Inches", unit: "in", text: $heightInches, keyboardType: .decimalPad)
            }
            VitalityTextField(title: "Current Weight", unit: "lb", text: $weightLb, keyboardType: .decimalPad)
        }
    }

    private func goalButton(_ goal: FitnessGoal) -> some View {
        Button {
            fitnessGoal = goal
        } label: {
            VStack(spacing: 8) {
                Image(systemName: goal.systemImage)
                    .font(.title3.weight(.bold))
                Text(goal.displayName.uppercased())
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(fitnessGoal == goal ? VitalityTheme.primary : VitalityTheme.text)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(fitnessGoal == goal ? VitalityTheme.primary.opacity(0.12) : VitalityTheme.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous)
                    .stroke(fitnessGoal == goal ? VitalityTheme.primary : VitalityTheme.outline)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveProfile() {
        let storedHeight: Double
        let storedWeight: Double
        if usesMetricUnits {
            guard let height = Double(heightCm), let weight = Double(weightKg) else {
                errorMessage = "Enter numeric height and weight values."
                return
            }
            storedHeight = height
            storedWeight = weight
        } else {
            guard let feet = Double(heightFeet), let inches = Double(heightInches), let weight = Double(weightLb) else {
                errorMessage = "Enter numeric height and weight values."
                return
            }
            storedHeight = UnitConversionService.convertFeetInchesToCm(feet: feet, inches: inches)
            storedWeight = UnitConversionService.convertLbToKg(weight)
        }
        do {
            let bodyFat = try HealthValidationService.optionalMeasurement(bodyFatText, invalidValue: .invalidBodyFat)
            let leanMass = try HealthValidationService.optionalMeasurement(leanMassText, invalidValue: .invalidLeanBodyMass)
            try HealthValidationService.validateProfile(
                dateOfBirth: dateOfBirth,
                heightCm: storedHeight,
                weightKg: storedWeight,
                bodyFatPercentage: bodyFat,
                leanBodyMassKg: leanMass
            )

            let profile = UserProfile(
                sex: sex,
                dateOfBirth: dateOfBirth,
                heightCm: storedHeight,
                weightKg: storedWeight,
                bodyFatPercentage: bodyFat,
                leanBodyMassKg: leanMass,
                activityLevel: activityLevel,
                fitnessGoal: fitnessGoal,
                usesMetricUnits: usesMetricUnits,
                isPregnantOrBreastfeeding: isPregnantOrBreastfeeding,
                hasMetabolismCondition: hasMetabolismCondition,
                medicationAffectsWeight: medicationAffectsWeight
            )
            modelContext.insert(profile)
            modelContext.insert(WeightEntry(weightKg: storedWeight))
            try modelContext.save()
            _ = try FitnessDataService.upsertDailyLog(for: Date(), profile: profile, in: modelContext)
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
