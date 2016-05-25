//
//  BluetoothManager.swift
//  BabyMonitorRecorder
//
//  Created by Jackie Yang on 5/25/16.
//  Copyright © 2016 Jackie Yang. All rights reserved.
//

import CoreBluetooth
import UIKit

class BluetoothManager: NSObject, CBCentralManagerDelegate {

    var centralManager:CBCentralManager?;
    var peripherals: [(CBPeripheral, String, NSNumber)]?;
    var lastBroadcastData: NSData?;
    var viewController = UIApplication.sharedApplication().keyWindow?.rootViewController
    var appDelegate : AppDelegate;
    var callbacks = CallbackList<(CBCentralManager, CBPeripheral, [String : AnyObject], NSNumber) -> Void>();
    var seen = 0;

    init(delegate: AppDelegate) {
        peripherals = [];
        appDelegate = delegate;
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil);
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        switch central.state {
        case .PoweredOff:
            let alert = UIAlertController(title: "Bluetooth is powered off",
                                          message: "Please turn on your bluetooth in Settings or Control Center to continue",
                                          preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            viewController?.presentViewController(alert, animated: true, completion: nil);
        case .Unauthorized:
            let alert = UIAlertController(title: "Bluetooth is not authencated", message: "Please give me the access for bluetooth in Settings.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            viewController?.presentViewController(alert, animated: true, completion: nil);
        case .Unknown:
            let alert = UIAlertController(title: "Unknown state for bluetooth", message: "Please try to reboot your device and try again.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            viewController?.presentViewController(alert, animated: true, completion: nil);
        case .Unsupported:
            let alert = UIAlertController(title: "Bluetooth is not supported", message: "Please find another phone and try agian.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            viewController?.presentViewController(alert, animated: true, completion: nil);
        case .PoweredOn:
            bluetoothReady();
        case .Resetting:
            break;
        }
    }

    func bluetoothReady() {
        centralManager?.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]);
    }

    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if(getDeviceStatus(peripheral)) {
            seen += 1;
            if let currentBroadcastData = advertisementData["kCBAdvDataManufacturerData"] {
                if (!currentBroadcastData.isEqual(lastBroadcastData)) {
                    print("device found: \(peripheral.identifier.UUIDString), \(currentBroadcastData)");
                    appDelegate.appendLogFile("\(NSDate().description): Device Found: \(peripheral.identifier.UUIDString), Data: \(currentBroadcastData), RSSI: \(RSSI) dB\n");
                    lastBroadcastData = currentBroadcastData as? NSData;
                }
            }
        }
        for callback in callbacks.list{
            callback.0(central, peripheral, advertisementData, RSSI);
        }
    }
    func getDeviceStatus(device:CBPeripheral) -> Bool {
        return appDelegate.monitoredUuids.contains(device.identifier.UUIDString);
    }
}