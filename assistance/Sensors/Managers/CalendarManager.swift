//
//  CalendarManager.swift
//  assistance
//
//  Created by Nickolas Guendling on 05/12/15.
//  Copyright © 2015 Darmstadt University of Technology. All rights reserved.
//

import Foundation

import EventKit

import RealmSwift

class CalendarManager: SensorManager {
    
    var collecting = false
    
    static let sharedManager = CalendarManager()
    
    let realm = try! Realm()
    let eventStore = EKEventStore()
    
    override init() {
        super.init()
        
        sensorType = "calendar"
        initSensorManager()
        
        if isActive() {
            start()
        }
    }
    
    override func needsSystemAuthorization() -> Bool {
        return EKEventStore.authorizationStatusForEntityType(.Event) != .Authorized
    }
    
    override func requestAuthorizationFromViewController(viewController: UIViewController, completed: (granted: Bool, error: NSError?) -> Void) {
        print(EKEventStore.authorizationStatusForEntityType(.Event).rawValue)
        if EKEventStore.authorizationStatusForEntityType(.Event) == .NotDetermined {
            eventStore.requestAccessToEntityType(.Event) {
                granted, error in
                
                if granted {
                    self.grantAuthorization()
                } else {
                    self.denySystemAuthorization()
                }
                
                completed(granted: granted, error: error)
            }
        } else if EKEventStore.authorizationStatusForEntityType(.Event) == .Denied {
            let calendarPermissionViewController = viewController.storyboard?.instantiateViewControllerWithIdentifier(String(CalendarPermissionViewController)) as! CalendarPermissionViewController
            viewController.presentViewController(calendarPermissionViewController, animated: true, completion: nil)
            
            completed(granted: false, error: nil)
        } else if EKEventStore.authorizationStatusForEntityType(.Event) == .Authorized {
            grantAuthorization()
        }
    }

    override func didStart() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "calendarChanged", name: EKEventStoreChangedNotification, object: nil)
        
        calendarChanged()
    }
    
    override func didStop() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
//        realm.delete(realm.objects(Calendar))
    }
    
    func calendarChanged() {
        
        collecting = true
        
        dispatch_async(dispatch_get_main_queue(), {
            _ = try? self.realm.write {
                self.realm.objects(Calendar).forEach { $0.isDeleted = true }
            }
        })
        
        let startDate = NSDate().dateByAddingTimeInterval(-60 * 60 * 24 * 7 * 10) // starting 10 weeks before today
        let endDate = NSDate().dateByAddingTimeInterval(60 * 60 * 24 * 365) // ending 1 year from today
        let predicate = eventStore.predicateForEventsWithStartDate(startDate, endDate: endDate, calendars: nil)
        eventStore.enumerateEventsMatchingPredicate(predicate) {
            event, _ in
            
            dispatch_async(dispatch_get_main_queue(), {
                let savedEvents = self.realm.objects(Calendar).filter("id == '\(event.eventIdentifier)'")
                _ = try? self.realm.write {
                    if savedEvents.count > 0 {
                        savedEvents.first!.isDeleted = false
                        savedEvents.first!.updatePropertiesWithEvent(event)
                    } else {
                        self.realm.add(Calendar(event: event))
                    }
                }
            })
        }
        
        collecting = false
    }
    
    override func sensorData() -> [Sensor] {
        if isActive() && shouldUpdate() && !collecting {
            return Array(realm.objects(Calendar).filter("isNew == true || isUpdated == true || isDeleted == true").toArray().prefix(20))
        }
        
        return [Sensor]()
    }
    
    override func sensorDataDidUpdate(data: [Sensor]) {
        _ = try? realm.write {
            for calendar in data {
                calendar.setSynced()
            }
        }
        
        if realm.objects(Calendar).count == 0 {
            didUpdate()
        }
    }
    
}
