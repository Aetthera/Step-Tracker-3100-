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
        // a way to update the app in background, as well as globally
        DispatchQueue.global(qos: .background).async {
            print("////////////////////////////")
            print("Attempting to fetch data...")
            self.readStepCountToday()
            self.readStepCountYesterday()
            self.readCaloriesCountToday()
            self.readStepCountThisWeek()
            
            print("Data Fetching Complete...")
            print("\(self.stepCountToday) steps today")
            print("\(self.caloriesBurnedToday) calories today")
            print("////////////////////////////")
            
            // reference
            // userdefault -> (k,v) ->store info in the app
            UserDefaults(suiteName: "group.iWalker")?.set(self.stepCountToday, forKey: "widgetStep")
            WidgetCenter.shared.reloadAllTimelines() // This will update the widget as well.
        }
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
    
    func readStepCountYesterday() {
        // to specify the type
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        // create our predicate
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())
        let startDate = calendar.startOfDay(for: yesterday!)
        let endDate = calendar.startOfDay(for: Date()) //Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // make the query
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in guard let result = result, let sum = result.sumQuantity() else{
            print("Failed to fetch data: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            // Update it in the main thread
            DispatchQueue.main.async {
                self.stepCountYesterday = steps
            }
        }
        
        // execute the query
        healthStore.execute(query)
    }
    
    func readCaloriesCountToday() {
        // type of the data
        
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .dietaryCalcium) else {
            return
        }
        
        // predicate
        let now = Date()
        let startDate = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        // make the query
        let query = HKSampleQuery(sampleType: caloriesType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {_, result, _ in guard let samples = result as? [HKQuantitySample] else { DispatchQueue.main.async {
            print("No Calories Data found")}
            return
        }
            
            //                                      act + resting
            let totalCalories = samples.reduce(0.0){$0 + $1.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
            DispatchQueue.main.async {
                self.caloriesBurnedToday = Int(totalCalories)
            }
        }
        
        // execute the query
        healthStore.execute(query)
    }
    
    func readStepCountThisWeek() {
        // step count - today
        // step count - yesterday
        // the last 7 days
        
        // type of data
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        //predicate
        let calendar = Calendar.current
        let today  = calendar.startOfDay(for: Date())
        // start of the week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return
        }
        
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: endOfWeek, options: .strictStartDate)
        
        // make the query
        // we need to make this query 7 times - init
        let query = HKStatisticsCollectionQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, anchorDate: startOfWeek, intervalComponents: DateComponents(day: 1))
        
        query.initialResultsHandler = {
            _, result, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("Error fetching Weekly steps: \(error.localizedDescription)")
                }
                return
            }
            
            var weeklySteps: [Int: Int] = [:] // empty dict
            
            result?.enumerateStatistics(from: startOfWeek, to: endOfWeek) {
                statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                    let day = calendar.component(.weekday, from: statistics.startDate)
                    weeklySteps[day] = steps
                }
            }
            
            DispatchQueue.main.async {
                self.thisWeekSteps = weeklySteps
                print("weeklySteps: \(self.thisWeekSteps)")
            }
        }
        
        healthStore.execute(query)
    }
}
