import Foundation

struct FoodReference: Identifiable {
    let id: String
    let name: String
    let referenceAmount: Double
    let measure: String
    let portionName: String
    let calories: Double

    static let sourceURL = URL(string: "https://www.studenthealth.gov.hk/english/resources/resources_bl/files/caloric_value_common_food.pdf")!
    // Reference portions from Hong Kong Department of Health's common-food table.
    static let foods: [FoodReference] = [
        .init(id: "rice", name: "Cooked white rice", referenceAmount: 186, measure: "g", portionName: "One bowl", calories: 242),
        .init(id: "brown-rice", name: "Cooked brown rice", referenceAmount: 195, measure: "g", portionName: "One bowl", calories: 218),
        .init(id: "bread", name: "White bread", referenceAmount: 25, measure: "g", portionName: "One slice", calories: 66),
        .init(id: "egg", name: "Cooked egg", referenceAmount: 50, measure: "g", portionName: "One large egg", calories: 78),
        .init(id: "banana", name: "Banana", referenceAmount: 118, measure: "g", portionName: "One medium banana", calories: 105),
        .init(id: "apple", name: "Apple with skin", referenceAmount: 138, measure: "g", portionName: "One medium apple", calories: 72),
        .init(id: "milk", name: "Whole milk", referenceAmount: 240, measure: "ml", portionName: "One cup", calories: 156),
        .init(id: "soy-milk", name: "Soya milk", referenceAmount: 240, measure: "ml", portionName: "One cup", calories: 132),
        .init(id: "tofu", name: "Tofu", referenceAmount: 100, measure: "g", portionName: "Reference portion", calories: 76),
        .init(id: "yogurt", name: "Plain yogurt", referenceAmount: 100, measure: "g", portionName: "Reference portion", calories: 72),
        .init(id: "oil", name: "Olive oil", referenceAmount: 5, measure: "g", portionName: "Five grams", calories: 45),
        .init(id: "ha-gau", name: "Steamed prawn dumplings", referenceAmount: 100, measure: "g", portionName: "Reference portion", calories: 160),
        .init(id: "siu-mai", name: "Siu mai", referenceAmount: 100, measure: "g", portionName: "Reference portion", calories: 200),
        .init(id: "noodles", name: "Cooked rice noodles", referenceAmount: 176, measure: "g", portionName: "One bowl", calories: 192)
    ]
}

enum FoodEnergyUnit: String, CaseIterable, Identifiable {
    case kcal, kJ
    var id: String { rawValue }
    func kilocalories(_ value: Double) -> Double { self == .kcal ? value : value / 4.184 }
}

enum FoodCalorieService {
    static func estimate(energy: Double, referenceAmount: Double, consumedAmount: Double, unit: FoodEnergyUnit = .kcal) throws -> Double {
        guard energy.isFinite, energy >= 0, referenceAmount.isFinite, referenceAmount > 0,
              consumedAmount.isFinite, consumedAmount > 0 else { throw FoodEstimateError.invalidAmount }
        let result = unit.kilocalories(energy) * consumedAmount / referenceAmount
        guard result.isFinite, result >= 0, result <= 20_000 else { throw FoodEstimateError.invalidAmount }
        return result
    }
}

enum FoodEstimateError: LocalizedError {
    case invalidAmount
    var errorDescription: String? { "Enter valid energy and a positive portion amount, up to 20,000 kcal in total.".localized }
}

struct EstimatedFood: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let calories: Double
    var note: String { L10n.format("%@ (%@): %@", name, amount, calories.caloriesText) }
}
