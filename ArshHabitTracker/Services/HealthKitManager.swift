//
//  HealthKitManager.swift
//  ArshHabitTracker
//
//  Read-only: steps today. Requires the HealthKit capability to be enabled
//  in Xcode's Signing & Capabilities (Xcode has to regenerate the
//  provisioning profile for the entitlement to take effect) — the
//  entitlements file and Info.plist usage strings are already wired up.
//

import Foundation
import Combine
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var todaysSteps: Int?
    @Published var isAuthorized = false
    @Published var statusMessage: String?

    private let store = HKHealthStore()

    private init() {}

    func requestAuthorizationAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "Health data isn't available on this device."
            return
        }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
            statusMessage = nil
            await refreshSteps()
        } catch {
            isAuthorized = false
            statusMessage = "Couldn't get Health authorization: \(error.localizedDescription)"
        }
    }

    func refreshSteps() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)

        let steps: Int? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: sum.map { Int($0) })
            }
            store.execute(query)
        }
        todaysSteps = steps
    }
}
