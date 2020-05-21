//  Copyright © 2019 Frontier Software Services, LTD. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import CoreBluetooth
import Foundation
import SwiftyBluetooth

class BluetoothHelper {
    
    private var recentlySeen:[String: Peripheral] = [:]
    
    public var delegate: BluetoothHelperDelegate?
    
    static let shared = BluetoothHelper()
    
    init() {
        Central.sharedInstance.asyncState(completion: {
            (btState) in
            print(btState)
            
            NotificationCenter.default.addObserver(forName: Central.CentralPeripheralDisconnected,
                                                   object: nil,
                                                   queue: nil) { (notification) in
                                                    let uuid = notification.userInfo!["uuid"] as! UUID
                                                    print(uuid.uuidString)
                                                    self.handleDisconnect(deviceId: uuid.uuidString)
            }
        })
    }
    
    func scanForNearbyDevices(with services:[String]?, completion: (([BluetoothDevice]?, Error?)->Void)? ) {
        var results = [BluetoothDevice]()
        
        recentlySeen.removeAll()
        
        SwiftyBluetooth.scanForPeripherals(withServiceUUIDs:services, timeoutAfter: 15) { scanResult in
            switch scanResult {
            case .scanStarted:
                return
            case .scanResult(let peripheral, _, let RSSI):
                
                if let name = peripheral.name {
                    let id = peripheral.identifier.uuidString
                    let device = BluetoothDevice(id: id, name: name)
                    
                    results.append(device)
                    let isNew = self.recentlySeen[id] == nil
                    
                    self.recentlySeen[id] = peripheral
                    
                    if isNew {
                        self.delegate?.onScanResult(device: device)
                    }
                }
            case .scanStopped(let error):
                let error: BluetoothDeviceError? = (error != nil) ? BluetoothDeviceError(tag: "scanError", description: error?.errorDescription) : nil
                
                completion?(results, error)
            }
        }
    }
    
    
    func scanForNearbyDevices(matching evalFunction: @escaping ((String)->Bool), completion: (([BluetoothDevice]?, Error?)->Void)? ) {
        var results = [BluetoothDevice]()
        
        recentlySeen.removeAll()
        SwiftyBluetooth.scanForPeripherals(withServiceUUIDs:nil, timeoutAfter: 15) { scanResult in
            switch scanResult {
            case .scanStarted:
                self.delegate?.onScanStateChanged(scanning: true)
                return
            case .scanResult(let peripheral, _, let RSSI):
                
                if let name = peripheral.name {
                    print("*",name)
                    if evalFunction(name) {
                        let id = peripheral.identifier.uuidString
                        let device = BluetoothDevice(id: id, name: name)
                        
                        results.append(device)
                        let isNew = self.recentlySeen[id] == nil
                        
                        self.recentlySeen[id] = peripheral
                        
                        if isNew {
                            self.delegate?.onScanResult(device: device)
                        }
                        
                    }
                    
                }
            case .scanStopped(let error):
                let error: BluetoothDeviceError? = (error != nil) ? BluetoothDeviceError(tag: "scanError", description: error?.errorDescription) : nil
                self.delegate?.onScanStateChanged(scanning: false)
                completion?(results, error)
            }
        }
    }
    
    func stopScan() {
        SwiftyBluetooth.stopScan()
    }
    
    func connectToDevice(device: String, completion: @escaping (Bool, Error?)->Void ) {
        guard let peripheral = self.recentlySeen[device] else {
            completion(false, BluetoothDeviceError(tag:"connectToDevice", description: "Unable to locate this device" ))
            return
        }
        
        peripheral.connect(withTimeout: 15) { result in
            switch result {
            case .success:
                self.handleConnect(to: peripheral) {
                    completion(true, nil)
                }
                
                break 
            case .failure(let error):
                self.handleDisconnect(deviceId: device)
                completion(false, BluetoothDeviceError(tag: "connect", description: error.localizedDescription))
                break
            }
        }
    }
    
    func userDisconnect(_ deviceId: String, completion: ((Bool, Error?)->Void)? ) {
        
        guard let device = recentlySeen[deviceId] else {
            completion?(false, BluetoothDeviceError(tag: "disconnect", description: "Device with id \(deviceId) not found"))
            return
        }
        
        device.disconnect(completion: { (result) in
            completion?(result.isSuccess, result.error)
        })
    }
    
    private func handleConnect(to device: Peripheral, completion: ()->Void?) {
        SwiftyBluetooth.stopScan()
        delegate?.onDeviceConnected(deviceId: device.identifier.uuidString)
        device.setNotifyCallback { userInfo in
            let charac = userInfo["characteristic"] as! CBCharacteristic
            if (userInfo["error"] as? SBError) != nil {
                // Deal with error
                
            } else if let data = charac.value {
                self.updateDeviceValue(on: device, service: charac.service.uuid.uuidString, characteristic: charac.uuid.uuidString, data: data, accessLevel: .notify)
            }
        }
        completion()
    }
    
    private func handleDisconnect(deviceId: String) {
        _ = self.recentlySeen[deviceId]
        delegate?.onDeviceDisconnected(deviceId: deviceId)
    }
    
    // MARK: - Read Characteristic
    func read(characteristic:String, from service:String, on deviceId:String) {
        guard let device = recentlySeen[deviceId] else { return; }
        
        device.readValue(ofCharacWithUUID: characteristic, fromServiceWithUUID: service) { result in
            switch result {
            case .success(let data):
                self.updateDeviceValue(on: device, service: service, characteristic: characteristic, data: data, accessLevel: .read)
                break
            case .failure(let error):
                print("read error", error.localizedDescription)
                if device.state != CBPeripheralState.connected {
                    self.delegate?.onDeviceDisconnected(deviceId: deviceId)
                }
                break
            }
        }
    }
    
    func write(data: Data, characteristic:String, to service: String, on deviceId:String,
               needsResponse: Bool = true) {
        guard let device = recentlySeen[deviceId] else { return; }
        let writeType = needsResponse ? CBCharacteristicWriteType.withResponse : CBCharacteristicWriteType.withoutResponse
        device.writeValue(ofCharacWithUUID: characteristic,
                          fromServiceWithUUID: service,
                          value: data, type: writeType) { result in
                            switch result {
                            case .success(let data):
                                print(data)
                                break
                            case .failure(let error):
                                print(error)
                                if device.state != CBPeripheralState.connected {
                                    self.delegate?.onDeviceDisconnected(deviceId: deviceId)
                                }
                                break
                            }
        }
    }
    
    //MARK: - Listen for events
    func listenFor(characteristic: String, on service: String, with device: String) {
        guard let device = recentlySeen[device] else { return; }
        device.setNotifyValue(toEnabled: true, forCharacWithUUID: characteristic, ofServiceWithUUID: service) { (isNotifying) in
            print("isNotifying", characteristic, isNotifying)
        }
    }
    
    func stopListeningFor(characteristic: String, on service: String, with device: String) {
        guard let device = recentlySeen[device] else { return; }
        device.setNotifyValue(toEnabled: false, forCharacWithUUID: characteristic, ofServiceWithUUID: service) { (isNotifying) in
        }
    }
    
    // MARK: - Respond to incoming data
    private func updateDeviceValue(on device:Peripheral, service: String, characteristic: String, data: Data, accessLevel: AccessLevel) {
        let deviceId = device.identifier.uuidString
        delegate?.onDataRecieved(deviceId: deviceId, service: service, characteristic: characteristic, data: data, accessLevel: accessLevel)
    }
    
}

protocol BluetoothHelperDelegate {
    
    func onScanResult(device: BluetoothDevice)
    
    func onScanStateChanged(scanning: Bool)
    
    func onDataRecieved(deviceId: String, service: String, characteristic: String, data: Data, accessLevel: AccessLevel)
    
    func onDeviceConnected(deviceId: String)
    
    func onDeviceDisconnected(deviceId: String)
}

