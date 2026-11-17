import SwiftUI

struct FoodCalorieGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VitalityScreen(title: "Calorie guide", subtitle: "Estimate your actual portion. Package or restaurant information takes priority over reference foods.") {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "How to estimate")
                            Text("1. Match the food and cooking method.")
                            Text("2. Check energy per serving or per 100 g/ml, then enter the amount you ate.")
                            Text("3. Include oil, sauces, toppings and drinks separately.")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "Read the portion, not just the number")
                            Text("A label says 250 kcal per 100 g. Eating 60 g gives 250 × 60 ÷ 100 = 150 kcal.")
                            Text("A reference bowl of cooked rice is about 242 kcal. Half that portion is about 121 kcal.")
                            Text("Weigh food when possible. Bowls and cups vary; compare with the listed reference weight.")
                                .foregroundStyle(VitalityTheme.textMuted)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Reference values vary by recipe and brand; they are estimates, not exact measurements.")
                        .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reference portions: Hong Kong Department of Health, 2011.")
                        Link("Food reference table", destination: FoodReference.sourceURL)
                        Link("Search more foods (CFS)", destination: URL(string: "https://www.cfs.gov.hk/english/nutrient/index.php")!)
                        Link("Understanding serving sizes", destination: URL(string: "https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label")!)
                    }
                    .font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(VitalityTheme.textMuted)
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct FoodPortionCalculator: View {
    let onApply: (Double, String) -> Void
    @State private var fromLabel = false
    @State private var foodID = FoodReference.foods[0].id
    @State private var useMeasuredAmount = false
    @State private var amountText = "1"
    @State private var labelName = ""
    @State private var labelEnergy = ""
    @State private var labelAmount = ""
    @State private var labelPer100 = true
    @State private var energyUnit: FoodEnergyUnit = .kcal
    @State private var foods: [EstimatedFood] = []
    init(startWithLabel: Bool = false, onApply: @escaping (Double, String) -> Void) {
        self.onApply = onApply
        _fromLabel = State(initialValue: startWithLabel)
    }
    private var food: FoodReference { FoodReference.foods.first { $0.id == foodID } ?? FoodReference.foods[0] }
    private var total: Double { foods.reduce(0) { $0 + $1.calories } }
    private var estimate: Double? {
        if fromLabel {
            guard let energy = Double(labelEnergy), let amount = Double(labelAmount) else { return nil }
            return try? FoodCalorieService.estimate(energy: energy, referenceAmount: labelPer100 ? 100 : 1,
                                                  consumedAmount: amount, unit: energyUnit)
        }
        guard let amount = Double(amountText) else { return nil }
        return try? FoodCalorieService.estimate(energy: food.calories,
                                              referenceAmount: useMeasuredAmount ? food.referenceAmount : 1, consumedAmount: amount)
    }

    var body: some View {
        VStack(spacing: 14) {
            VitalityCard(padding: 10) {
                Picker("Estimate method", selection: $fromLabel) {
                    Text("Common foods").tag(false)
                    Text("Nutrition label").tag(true)
                }.pickerStyle(.segmented)
            }
            if fromLabel { labelFields } else { commonFoodFields }
            MetricCard(title: "Portion estimate", value: estimate?.caloriesText ?? "--",
                       detail: fromLabel ? "Energy scales with the portion you actually eat." : "Based on the selected reference portion.",
                       tint: VitalityTheme.warning, systemImage: "fork.knife")
            Button("Add to meal") { addFood() }
                .buttonStyle(.bordered).tint(VitalityTheme.primary)
                .disabled(estimate == nil)
            if !foods.isEmpty {
                VitalityCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VitalitySectionLabel(text: "Meal estimate")
                        ForEach(foods) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.subheadline.weight(.medium))
                                    Text(item.amount).font(.caption).foregroundStyle(VitalityTheme.textMuted)
                                }
                                Spacer()
                                Text(item.calories.caloriesText).font(.subheadline).monospacedDigit()
                                Button {
                                    foods.removeAll { $0.id == item.id }
                                    updateTotal()
                                } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel(L10n.format("Remove %@", item.name))
                            }
                        }
                        Divider()
                        Text(total.caloriesText).font(.title2.bold()).foregroundStyle(VitalityTheme.warning)
                        if total > 20_000 {
                            Text("Meal total must not exceed 20,000 kcal.").font(.footnote).foregroundStyle(VitalityTheme.warning)
                        }
                    }
                }
            }
        }
        .onChange(of: foodID) { _, _ in amountText = useMeasuredAmount ? String(food.referenceAmount) : "1" }
        .onChange(of: useMeasuredAmount) { wasMeasured, _ in
            if let value = Double(amountText), value.isFinite {
                amountText = String(wasMeasured ? value / food.referenceAmount : value * food.referenceAmount)
            }
        }
    }

    private var commonFoodFields: some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Food", selection: $foodID) {
                    ForEach(FoodReference.foods) { Text($0.name.localized).tag($0.id) }
                }.tint(VitalityTheme.primary)
                Text(L10n.format("%@ (%@ %@) ≈ %@", food.portionName.localized,
                                 food.referenceAmount.formatted(.number.locale(L10n.locale)), food.measure.localized, food.calories.caloriesText))
                    .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                Picker("Amount basis", selection: $useMeasuredAmount) {
                    Text("Servings").tag(false)
                    Text(food.measure.localized).tag(true)
                }.pickerStyle(.segmented)
                TextField("Amount eaten", text: $amountText).keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Amount eaten")
                Button("Food not listed? Use its nutrition label.") { fromLabel = true }
                    .font(.footnote).tint(VitalityTheme.primary)
            }
        }
    }

    private var labelFields: some View {
        VStack(spacing: 12) {
            VitalityTextField(title: "Food name (optional)", unit: nil, text: $labelName)
            VitalityCard {
                VStack(spacing: 12) {
                    Picker("Label basis", selection: $labelPer100) {
                        Text("Per 100 g/ml").tag(true)
                        Text("Per serving").tag(false)
                    }.pickerStyle(.segmented)
                    Picker("Energy unit", selection: $energyUnit) {
                        ForEach(FoodEnergyUnit.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            VitalityTextField(title: "Energy on label", unit: energyUnit.rawValue, text: $labelEnergy, keyboardType: .decimalPad)
            VitalityTextField(title: "Amount eaten", unit: labelPer100 ? "g / ml" : "Servings", text: $labelAmount, keyboardType: .decimalPad)
        }
    }

    private func addFood() {
        guard let estimate else { return }
        let name = fromLabel ? (labelName.trimmingCharacters(in: .whitespaces).isEmpty ? "Nutrition label".localized : labelName) : food.name.localized
        let amount = fromLabel ? labelAmount : amountText
        let unit = fromLabel ? (labelPer100 ? "g / ml" : "Servings") : (useMeasuredAmount ? food.measure : "Servings")
        foods.append(EstimatedFood(name: name, amount: L10n.format("%@ %@", amount, unit.localized), calories: estimate))
        updateTotal()
    }

    private func updateTotal() {
        onApply(total.rounded(), foods.map(\.note).joined(separator: "\n"))
    }
}
