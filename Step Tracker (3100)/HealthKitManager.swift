//
//  HealthKitManager.swift
//  Step Tracker (3100)
//
//  Created by Alena Belova  on 2025-01-23.
//

import Foundation
import HealthKit
import WidgetKit // this is for widgets

class HealthKitManager: ObservableObject {
    
    // app -> healthStore -> HKStats -> ////// -> Apple HealthKit
    // app <----------------------------------- Apple HeathKit
    //          stream of data
    // type of data, convert the data type
    // HKUNIT -> Int or Double
    // 1, 1, 1, 1, 1, 1, 1, -> add them cumalatuvly
    // a need to write our own filter mechanism
    // start date, end date, optuons (rules) -> (predicate)
    
    
    var healthStore = HKHealthStore()
    
    // step count, calories, weekly step count
    @Published var stepCountToday: Int = 0
    @Published var stepCountYesterday: Int = 0
    @Published var caloriesBurnedToday: Int = 0
    
    // weekly step count
    //                              day: no.of.steps
    @Published var thisWeekSteps: [Int: Int] = [
        1:0,
        2:0,
        3:0,
        4:0,
        5:0,
        6:0,
        7:0
    ]
    
    // singleton design pattern
    static let shared = HealthKitManager()
    
    // init
    init() {
        // request for permissions
    }
    
    func requestAuthorization() {
        // read the health data -> toReads
        let toReads = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier:  .activeEnergyBurned)!
        ])
        
        // check if healthStore is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Failed to fetch data")
            return
        }
        
        // request for auth
        healthStore.requestAuthorization(toShare: nil, read: toReads) { success, error in
            DispatchQueue.main.async {
                if success {
                    //fetching all data -> steps, calories ...
                    self.fetchAllData()
                    // setup a background observer
                } else {
                    print("\(String(describing:error))")
                }
            } // data is updated in different thread
            // UI is updated in main thread
            // even if the data is changed, UI wont get updated
            // UI -> Main Thread
            // HKManager -> other thread
        }
    }
    
    func fetchAllData() {
        
    }
    
    // reading today's step count
    func readStepCountToday() {
        //type of data -> step count
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }
            
            // start date, end date, rules
            let now = Date()
            let startDate = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
             // make the query
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum){_, result, error in guard let result = result, let sum = result.sumQuantity() else { print("Fainled to feyfj information: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
            return
        }
            
        // steps
        let steps = Int(sum.doubleValue(for: HKUnit.count()))
        //update our steps
            DispatchQueue.main.async {
                self.stepCountToday = steps
            }
        }
        
        // execute the query
        healthStore.execute(query)
    }
}
