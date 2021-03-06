//
//  AppDelegate.swift
//  BabyMonitorRecorder
//
//  Created by Jackie Yang on 11/19/15.
//  Copyright (c) 2015 Jackie Yang. All rights reserved.
//


import UIKit

enum ConnectState {
    case Connecting
    case ToBeConfigure
    case Connected
    case Disconnected
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let logFileOpQueue = dispatch_queue_create("me.jackieyang.babymonitor.fileop", nil);
    var logFileHandle:NSFileHandle?;
    var monitoredUuids: [String] = [];
    var bluetoothManager: BluetoothManager!;
    var state = ConnectState.Connecting
    let stateCallbacks = CallbackList<(ConnectState) -> Void>();
    var checkStateTimer: NSTimer!;
    var disconnectCount = 0;
    let disconnectCountThreshold = 100;

    func updateConnectionStatus() {
        if bluetoothManager.seen != 0 {
            state = ConnectState.Connected;
        } else {
            if monitoredUuids.count == 0 {
                state = ConnectState.ToBeConfigure;
            } else {
                state = ConnectState.Disconnected;
            }
        }
        bluetoothManager.seen = 0
        print("fired: \(state)")
        for callback in stateCallbacks.list {
            callback.0(state)
        }
        if state == .Disconnected {
            disconnectCount += 1;
        } else {
            disconnectCount = 0;
        }

        if disconnectCount >= disconnectCountThreshold {
             
        }
    }

    func createLogFile(date: String) {
        dispatch_async(logFileOpQueue) {
            self.logFileHandle?.closeFile();
            if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
                let path = dir.stringByAppendingPathComponent("data\(date).txt");

                if let tempLogFileHandle = NSFileHandle(forUpdatingAtPath: path) {
                    self.logFileHandle = tempLogFileHandle;
                } else {
                    NSFileManager.defaultManager().createFileAtPath(path, contents: nil, attributes: nil);
                    self.logFileHandle = NSFileHandle(forUpdatingAtPath: path)!;
                }
                self.logFileHandle?.seekToEndOfFile();
            }
        }
    }

    func appendLogFile(content: String) {
        dispatch_async(logFileOpQueue) {
            if let data = content.dataUsingEncoding(NSUTF8StringEncoding) {
                self.logFileHandle?.writeData(data)
            }
        }
    }

    func syncLogFile() {
        dispatch_async(logFileOpQueue) {
            self.logFileHandle?.synchronizeFile();
        }
    }

    func readLogFile(completion: ((result: String?) -> Void)){
        dispatch_async(logFileOpQueue) {
            if let handle = self.logFileHandle {
                handle.seekToFileOffset(0)
                completion(result: String(data: handle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding))
            } else {
                completion(result: nil)
            }
        }
    }

    func closeLogFile() {
        dispatch_async(logFileOpQueue) {
            self.logFileHandle?.closeFile();
        }
    }

    func saveUserDefaults(){
        objc_sync_enter(self)
        func uniq<S: SequenceType, E: Hashable where E==S.Generator.Element>(source: S) -> [E] {
            var seen: [E:Bool] = [:]
            return source.filter({ seen.updateValue(true, forKey: $0) == nil })
        }

        monitoredUuids = uniq(monitoredUuids);

        userDefaults.setObject(monitoredUuids, forKey: monitoredUuidsPrefKey);
        userDefaults.synchronize();

        checkStateTimer.invalidate()
        state = .Connecting
        for callback in stateCallbacks.list {
            callback.0(state)
        }
        bluetoothManager.seen = 0
        checkStateTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: #selector(AppDelegate.updateConnectionStatus), userInfo: nil, repeats: true)
        objc_sync_exit(self)
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Override point for customization after application launch.
        bluetoothManager = BluetoothManager(delegate: self)
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil))
        let dateFormator = NSDateFormatter()
        dateFormator.dateFormat = "yyyy-MM-dd-HH-mm"
        createLogFile(dateFormator.stringFromDate(NSDate()))
        appendLogFile("\(NSDate().description): Program Starts\n");
        if let uuidArray = userDefaults.arrayForKey(monitoredUuidsPrefKey) as? [String] {
            monitoredUuids = uuidArray;
        } else {
            saveUserDefaults();
        }
        if monitoredUuids.count == 0 {
            state = ConnectState.ToBeConfigure;
        }
        checkStateTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: #selector(AppDelegate.updateConnectionStatus), userInfo: nil, repeats: true)
        return true
    }


    func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        print(UIApplication.sharedApplication().scheduledLocalNotifications);
        UIApplication.sharedApplication().cancelAllLocalNotifications();
        let localNotification:UILocalNotification = UILocalNotification()
        localNotification.alertBody = "Recorder goes background!"
        localNotification.fireDate = NSDate(timeIntervalSinceNow: 0.5)
        localNotification.soundName = UILocalNotificationDefaultSoundName
        localNotification.category = "invite"
        UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
        syncLogFile()
    }


    func applicationDidEnterBackground(application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    }


    func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        syncLogFile()
    }


    func applicationDidBecomeActive(application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


    func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        syncLogFile()
        closeLogFile()
    }

}
