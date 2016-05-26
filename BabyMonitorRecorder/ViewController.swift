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
let monitoredUuidsPrefKey = "monitoredUuids";
let dataFileName = "data.txt";




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
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

    override func viewDidLoad() {
        super.viewDidLoad();
        if let uuidArray = userDefaults.arrayForKey(monitoredUuidsPrefKey) as? [String] {
            appDelegate.monitoredUuids = uuidArray;
        } else {
            appDelegate.saveUserDefaults();
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated);
        uuidTableView.reloadData();
    }

    @IBAction func clearAll(sender: UIButton) {
        appDelegate.monitoredUuids.removeAll();
        appDelegate.saveUserDefaults();
        uuidTableView.reloadData();
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appDelegate.monitoredUuids.count;
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let newCell = UITableViewCell(style: .Default, reuseIdentifier: "cell");
        newCell.textLabel?.text = appDelegate.monitoredUuids[indexPath.row];
        return newCell;
    }
}

class HistoryViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated);
        textView.text = "loading..."
        
        appDelegate.readLogFile() {
            (result: String?) in let text = result!
            dispatch_async(dispatch_get_main_queue()) {
                self.textView.text = text
            }
        }
    }
}


class ViewController: UITableViewController {

    @IBOutlet var peripheralTableView: UITableView!

    var centralManager:CBCentralManager?;
    var peripherals = [(CBPeripheral, String, NSNumber)]();
    var lastBroadcastData: NSData?;
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var index: Int?;

    override func viewDidLoad() {
        super.viewDidLoad();
        // Do any additional setup after loading the view, typically from a nib.
        peripheralTableView.editing = true;
    }

    override func viewWillAppear(animated: Bool) {
        self.appDelegate.bluetoothManager.callbacks.addCallback(updateDevices);
    }

    override func viewWillDisappear(animated: Bool) {
        if let index = index {
            self.appDelegate.bluetoothManager.callbacks.removeCallback(index)
        }
    }

    func updateDevices(manager: CBCentralManager, peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber){
        let newPeripheralElem = (peripheral, "\(advertisementData)", RSSI);
        for (idx, peripheralElem) in peripherals.enumerate() {
            if peripheralElem.0.identifier.UUIDString.isEqual(peripheral.identifier.UUIDString) {
                peripherals[idx] = newPeripheralElem;
                if let oldCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: idx, inSection: 0)) as? PeripheralTableViewCell {
                    setCellText(oldCell, with: newPeripheralElem);
                }
                return;
            }
        }
        peripherals.append(newPeripheralElem);
        print("try to create a new cell: \(newPeripheralElem.0.identifier.UUIDString)");
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: peripherals.count - 1, inSection: 0)], withRowAnimation: .Automatic);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("cell count: \(peripherals.count)")
        return peripherals.count;
    }

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let itemNumber = indexPath.item;
        if peripherals.count > itemNumber {
            let itemPeripheral = peripherals[itemNumber];
            cell.setSelected(appDelegate.bluetoothManager.getDeviceStatus(itemPeripheral.0), animated: false)
            if appDelegate.bluetoothManager.getDeviceStatus(itemPeripheral.0) {
                tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: .None);
            }
            print("set selected \(appDelegate.bluetoothManager.getDeviceStatus(itemPeripheral.0)) for \(itemPeripheral.0.identifier.UUIDString)")
            if let peripheralCell = cell as? PeripheralTableViewCell {
                setCellText(peripheralCell, with: itemPeripheral);
            }
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        print("create a new cell: \(indexPath.row)")
        let newCell = tableView.dequeueReusableCellWithIdentifier("PeripheralTableViewCell", forIndexPath: indexPath) as! PeripheralTableViewCell;
        let itemNumber = indexPath.item;
        if peripherals.count > itemNumber {
            let itemPeripheral = peripherals[itemNumber];
            setCellText(newCell, with: itemPeripheral);
            return newCell;
        }
        newCell.setText("", "", "");
        return newCell;
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        appDelegate.monitoredUuids.append(peripherals[indexPath.row].0.identifier.UUIDString);
        appDelegate.saveUserDefaults()
        print(userDefaults)
    }

    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let idx = appDelegate.monitoredUuids.indexOf(peripherals[indexPath.row].0.identifier.UUIDString) {
            appDelegate.monitoredUuids.removeAtIndex(idx);
            appDelegate.saveUserDefaults()
        }
        print(userDefaults)
    }

}

class DefaultViewcontroller: UIViewController {

    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var stateIcon: UIImageView!
    @IBOutlet weak var stateText: UILabel!

    var index: Int?;
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let iconMap: [ConnectState: UIImage?] = [.Connecting: UIImage.init(named: "Disconnected")!,
                                            .ToBeConfigure: UIImage.init(named: "Disconnected")!,
                                            .Disconnected: UIImage.init(named: "Disconnected")!,
                                            .Connected: UIImage.init(named: "Connected")!]

    let labelMap: [ConnectState: String?] = [.Connecting: "Connecting...",
                                             .ToBeConfigure: "Not Configured",
                                             .Disconnected: "Disconnected :(",
                                             .Connected: "Connected :)"]

    let textMap: [ConnectState: String?] = [.Connecting: NSLocalizedString("connectionState.connecting.text", comment: ""),
                                            .ToBeConfigure: NSLocalizedString("connectionState.tobeconfigure.text", comment: ""),
                                            .Disconnected: NSLocalizedString("connectionState.disconnected.text", comment: ""),
                                            .Connected: NSLocalizedString("connectionState.connected.text", comment: "")]


    override func viewWillAppear(animated: Bool) {
        updateInterface(self.appDelegate.state)
        self.appDelegate.stateCallbacks.addCallback(updateInterface);
    }

    override func viewWillDisappear(animated: Bool) {
        if let index = index {
            self.appDelegate.stateCallbacks.removeCallback(index)
        }
    }

    func updateInterface(state: ConnectState) {
        stateIcon.image = iconMap[state]!
        stateLabel.text = labelMap[state]!
        stateText.text = textMap[state]!
    }
    
}
