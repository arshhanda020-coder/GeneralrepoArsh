//
//  BarcodeLookupService.swift
//  ArshHabitTracker
//
//  Open Food Facts is free and needs no API key — a real product database,
//  which a barcode number needs (AI can't reliably know what a UPC maps to).
//

import Foundation

struct BarcodeNutrition {
    let productName: String?
    let calories: Int?
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?
    /// True when these are per-100g values rather than per-serving (Open Food Facts
    /// doesn't always define a serving size).
    let isPer100g: Bool
}

actor BarcodeLookupService {
    static let shared = BarcodeLookupService()

    private init() {}

    enum LookupError: LocalizedError {
        case notFound
        case requestFailed

        var errorDescription: String? {
            switch self {
            case .notFound: return "No product found for that barcode."
            case .requestFailed: return "Couldn't reach the product database."
            }
        }
    }

    func lookup(barcode: String) async throws -> BarcodeNutrition {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw LookupError.requestFailed
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LookupError.requestFailed
        }
        guard (json["status"] as? Int) == 1, let product = json["product"] as? [String: Any] else {
            throw LookupError.notFound
        }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let name = product["product_name"] as? String

        if let calories = nutriments["energy-kcal_serving"] as? Double {
            return BarcodeNutrition(
                productName: name,
                calories: Int(calories),
                proteinGrams: nutriments["proteins_serving"] as? Double,
                carbsGrams: nutriments["carbohydrates_serving"] as? Double,
                fatGrams: nutriments["fat_serving"] as? Double,
                isPer100g: false
            )
        }

        let caloriesPer100 = (nutriments["energy-kcal_100g"] as? Double) ?? (nutriments["energy-kcal"] as? Double)
        return BarcodeNutrition(
            productName: name,
            calories: caloriesPer100.map(Int.init),
            proteinGrams: nutriments["proteins_100g"] as? Double,
            carbsGrams: nutriments["carbohydrates_100g"] as? Double,
            fatGrams: nutriments["fat_100g"] as? Double,
            isPer100g: true
        )
    }
}
