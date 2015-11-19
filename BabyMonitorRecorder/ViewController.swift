//
//  ViewController.swift
//  BabyMonitorRecorder
//
//  Created by Jackie Yang on 11/19/15.
//  Copyright (c) 2015 Jackie Yang. All rights reserved.
//


import UIKit
import CoreBluetooth

var userDefaults = NSUserDefaults.standardUserDefaults();
var monitoredUuids: [String] = [];
let monitoredUuidsPrefKey = "monitoredUuids";
let dataFileName = "data.txt";


func saveUserDefaults(){
    func uniq<S: SequenceType, E: Hashable where E==S.Generator.Element>(source: S) -> [E] {
        var seen: [E:Bool] = [:]
        return source.filter({ seen.updateValue(true, forKey: $0) == nil })
    }

    monitoredUuids = uniq(monitoredUuids);

    userDefaults.setObject(monitoredUuids, forKey: monitoredUuidsPrefKey);
    userDefaults.synchronize();
}

class PeripheralTableViewCell: UITableViewCell {

    @IBOutlet weak var textDeviceName: UILabel!
    @IBOutlet weak var textRssiValue: UILabel!
    @IBOutlet weak var textAdData: UITextView!

    func setText(deviceName: String, _ rssiValue: String, _ adData: String) {
        textDeviceName.text = deviceName;
        textRssiValue.text = rssiValue;
        textAdData.text = adData;
    }
}

class FavoritesViewController: UITableViewController {

    @IBOutlet var uuidTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad();
        if let uuidArray = userDefaults.arrayForKey(monitoredUuidsPrefKey) as? [String] {
            monitoredUuids = uuidArray;
        } else {
            saveUserDefaults();
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated);
        uuidTableView.reloadData();
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return monitoredUuids.count;
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let newCell = UITableViewCell(style: .Default, reuseIdentifier: "cell");
        newCell.textLabel?.text = monitoredUuids[indexPath.row];
        return newCell;
    }
}

class HistoryViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!

    func readDataFile() -> String {
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(dataFileName);

            var filehandle:NSFileHandle;
            if let testfilehendle = NSFileHandle(forUpdatingAtPath: path) {
                filehandle = testfilehendle;
            } else {
                NSFileManager.defaultManager().createFileAtPath(path, contents: nil, attributes: nil);
                filehandle = NSFileHandle(forUpdatingAtPath: path)!;
            }

            return String(data: filehandle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)!;
        }
        return "";
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated);
        textView.text = readDataFile();
    }
}


class ViewController: UITableViewController, CBCentralManagerDelegate {

    @IBOutlet var peripheralTableView: UITableView!

    var centralManager:CBCentralManager?;
    var peripherals: [(CBPeripheral, String, NSNumber)]?;

    func appendToDataFile(string: String) {
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(dataFileName);

            var filehandle:NSFileHandle;
            if let testfilehendle = NSFileHandle(forUpdatingAtPath: path) {
                filehandle = testfilehendle;
            } else {
                NSFileManager.defaultManager().createFileAtPath(path, contents: nil, attributes: nil);
                filehandle = NSFileHandle(forUpdatingAtPath: path)!;
            }
            filehandle.seekToEndOfFile();

            if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
                filehandle.writeData(data)
            }
            filehandle.closeFile();
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad();
        // Do any additional setup after loading the view, typically from a nib.
        peripherals = [];
        centralManager = CBCentralManager(delegate: self, queue: nil);
        peripheralTableView.editing = true;
        if let uuidArray = userDefaults.arrayForKey(monitoredUuidsPrefKey) as? [String] {
            monitoredUuids = uuidArray;
        } else {
            saveUserDefaults();
        }
        appendToDataFile("\(NSDate().description): Program Starts");
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        switch central.state {
        case .PoweredOff:
            let alert = UIAlertController(title: "Bluetooth is powered off",
                message: "Please turn on your bluetooth in Settings or Control Center to continue",
                preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            self.presentViewController(alert, animated: true, completion: nil);
        case .Unauthorized:
            let alert = UIAlertController(title: "Bluetooth is not authencated", message: "Please give me the access for bluetooth in Settings.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            self.presentViewController(alert, animated: true, completion: nil);
        case .Unknown:
            let alert = UIAlertController(title: "Unknown state for bluetooth", message: "Please try to reboot your device and try again.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            self.presentViewController(alert, animated: true, completion: nil);
        case .Unsupported:
            let alert = UIAlertController(title: "Bluetooth is not supported", message: "Please find another phone and try agian.", preferredStyle: .Alert);
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil));
            self.presentViewController(alert, animated: true, completion: nil);
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
            print("device found: \(peripheral.identifier.UUIDString), \(advertisementData)");
            appendToDataFile("\(NSDate().description): Device Found: \(peripheral.identifier.UUIDString), \(advertisementData)");
        }
        let newPeripheralElem = (peripheral, "\(advertisementData)", RSSI);
        for (idx, peripheralElem) in peripherals!.enumerate() {
            if peripheralElem.0.identifier.isEqual(peripheral.identifier) {
                peripherals![idx] = newPeripheralElem;
                if let oldCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: idx, inSection: 0)) as? PeripheralTableViewCell {
                    setCellText(oldCell, with: newPeripheralElem);
                    return;
                }
            }
        }
        peripherals!.append(newPeripheralElem);
        print("try to create a new cell");
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: peripherals!.count - 1, inSection: 0)], withRowAnimation: .Automatic);
    }

    func setCellText(cell:PeripheralTableViewCell, with peripheralElem: (CBPeripheral, String, NSNumber)) {
        let (itemPeripheral, itemAdData, itemRssiValue) = peripheralElem;
        var itemDeviceName: String;
        if let name = itemPeripheral.name {
            itemDeviceName = name;
        } else {
            itemDeviceName = "NO NAME";
        }
        cell.setText(itemDeviceName, "\(itemRssiValue) dB", itemAdData);
    }

    func getDeviceStatus(device:CBPeripheral) -> Bool {
        return monitoredUuids.contains(device.identifier.UUIDString);
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("cell count: \(peripherals!.count)")
        return peripherals!.count;
    }

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let itemNumber = indexPath.item;
        if peripherals!.count > itemNumber {
            let itemPeripheral = peripherals![itemNumber];
            cell.setSelected(getDeviceStatus(itemPeripheral.0), animated: false)
            if getDeviceStatus(itemPeripheral.0) {
                tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: .None);
            }
            print("set selected \(getDeviceStatus(itemPeripheral.0)) for \(itemPeripheral.0.identifier.UUIDString)")
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        print("create a new cell: \(indexPath.row)")
        let newCell = tableView.dequeueReusableCellWithIdentifier("PeripheralTableViewCell", forIndexPath: indexPath) as! PeripheralTableViewCell;
        let itemNumber = indexPath.item;
        if peripherals!.count > itemNumber {
            let itemPeripheral = peripherals![itemNumber];
            setCellText(newCell, with: itemPeripheral);
            return newCell;
        }
        newCell.setText("", "", "");
        return newCell;
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        monitoredUuids.append(peripherals![indexPath.row].0.identifier.UUIDString);
        saveUserDefaults()
        print(userDefaults)
    }

    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let idx = monitoredUuids.indexOf(peripherals![indexPath.row].0.identifier.UUIDString) {
            monitoredUuids.removeAtIndex(idx);
            saveUserDefaults()
        }
        print(userDefaults)
    }

}
