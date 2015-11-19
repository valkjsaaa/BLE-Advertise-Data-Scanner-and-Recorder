//
//  ViewController.swift
//  BabyMonitorRecorder
//
//  Created by Jackie Yang on 11/19/15.
//  Copyright (c) 2015 Jackie Yang. All rights reserved.
//


import UIKit
import CoreBluetooth

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


class ViewController: UITableViewController, CBCentralManagerDelegate {

    @IBOutlet var peripheralTableView: UITableView!

    var centralManager:CBCentralManager?;
    var peripherals: [(CBPeripheral, String, NSNumber)]?;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        peripherals = [];
        centralManager = CBCentralManager(delegate: self, queue: nil);
        peripheralTableView.editing = true;
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
        let newPeripheralElem = (peripheral, "\(advertisementData)", RSSI);
        for (idx, peripheralElem) in peripherals!.enumerate() {
            if peripheralElem.0 == peripheral {
                peripherals![idx] = newPeripheralElem;
                if let oldCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: idx, inSection: 0)) as? PeripheralTableViewCell {
                    setCellText(oldCell, with: newPeripheralElem);
                    return;
                }
            }
        }
        peripherals!.append(newPeripheralElem);
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

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals!.count;
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let newCell = tableView.dequeueReusableCellWithIdentifier("PeripheralTableViewCell") as! PeripheralTableViewCell;
        let itemNumber = indexPath.item;
        if peripherals!.count > itemNumber {
            let itemPeripheral = peripherals![itemNumber];
            setCellText(newCell, with: itemPeripheral);
        }
        newCell.setText("", "", "");
        return newCell;
    }

}
