import Foundation

enum UnitConversionService {
    static func convertLbToKg(_ pounds: Double) -> Double {
        pounds * 0.45359237
    }

    static func convertKgToLb(_ kilograms: Double) -> Double {
        kilograms / 0.45359237
    }

    static func convertFeetInchesToCm(feet: Double, inches: Double) -> Double {
        ((feet * 12) + inches) * 2.54
    }
}
