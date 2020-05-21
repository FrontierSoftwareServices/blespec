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


import Foundation

public class BluetoothManager: BluetoothHelperDelegate {
    
    public static let shared = BluetoothManager()
    public var delegate: BluetoothManagerDelegate?
    
    private var registeredEndpointTypes = [AccessLevel:[String: BluetoothData.Type]]()
    private var registeredEndpoints = [String: BluetoothEndpoint]()
    private var subscribedEndpoints = [String: AnyDataSubscriber]()
    
    init() {
        BluetoothHelper.shared.delegate = self
        registeredEndpointTypes.updateValue([:], forKey: .read)
        registeredEndpointTypes.updateValue([:], forKey: .writeWithResponse)
        registeredEndpointTypes.updateValue([:], forKey: .writeNoResponse)
        registeredEndpointTypes.updateValue([:], forKey: .notify)
    }
    
    public func registerEndpoint(_ endpoint: BluetoothEndpoint, packetType: BluetoothData.Type) {
        registeredEndpoints.updateValue(endpoint, forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.read]?.updateValue(packetType, forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.writeWithResponse]?.updateValue(packetType, forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.notify]?.updateValue(packetType, forKey: endpoint.key)

    }
    
    public func registerEndpoint(_ endpoint: BluetoothEndpoint, packetType: BluetoothData.Type, accessLevel: AccessLevel) {
        registeredEndpoints.updateValue(endpoint, forKey: endpoint.key)
        registeredEndpointTypes[accessLevel]?.updateValue(packetType, forKey: endpoint.key)
    }
    
    public func unregisterEndpoint(_ endpoint: BluetoothEndpoint) {
        registeredEndpoints.removeValue(forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.read]?.removeValue(forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.writeWithResponse]?.removeValue(forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.writeNoResponse]?.removeValue(forKey: endpoint.key)
        registeredEndpointTypes[AccessLevel.notify]?.removeValue(forKey: endpoint.key)
    }
    
    public func unregisterEndpoint(_ endpoint: BluetoothEndpoint, accessLevel: AccessLevel) {
        registeredEndpointTypes[accessLevel]?.removeValue(forKey: endpoint.key)
                
        if isRegistered(endpoint, accessLevel: .read) {
            return
        }
        
        if isRegistered(endpoint, accessLevel: .writeWithResponse) {
            return
        }
        
        if isRegistered(endpoint, accessLevel: .notify) {
            return
        }
        
        registeredEndpoints.removeValue(forKey: endpoint.key)
    }
    
    public func isRegistered(_ endpoint: BluetoothEndpoint ,accessLevel: AccessLevel) -> Bool {
        return registeredEndpointTypes[accessLevel]?.keys.contains(endpoint.key) ?? false
    }
    
    public func allRegisteredEndpoints() -> [BluetoothEndpoint] {
        return Array(self.registeredEndpoints.values)
    }
    
    public func getRegisteredEndpoint(_ service: String, _ characteristic: String) -> BluetoothEndpoint? {
        let key = BluetoothEndpoint.createKey(service: service, characteristic: characteristic)
        if let endpoint = registeredEndpoints[key] {
            return endpoint
        }
        return nil
    }
    
    public func getAccessLevels(_ endpoint: BluetoothEndpoint) -> [AccessLevel] {
        let key = endpoint.key
        
        var access = [AccessLevel]()
        
        if registeredEndpointTypes[.read]?[key] != nil { access.append(.read)}
        if registeredEndpointTypes[.writeWithResponse]?[key] != nil { access.append(.writeWithResponse)}
        if registeredEndpointTypes[.writeNoResponse]?[key] != nil { access.append(.writeNoResponse)}
        if registeredEndpointTypes[.notify]?[key] != nil { access.append(.notify)}
        
        return access;
    }
    
    public func getAccessLevels(_ service: String, _ characteristic: String) -> [AccessLevel] {
        let key = BluetoothEndpoint.createKey(service: service, characteristic: characteristic)
        
        var access = [AccessLevel]()
        
        if registeredEndpointTypes[.read]?[key] != nil { access.append(.read)}
        if registeredEndpointTypes[.writeWithResponse]?[key] != nil { access.append(.writeWithResponse)}
        if registeredEndpointTypes[.writeNoResponse]?[key] != nil { access.append(.writeWithResponse)}
        if registeredEndpointTypes[.notify]?[key] != nil { access.append(.notify)}
        
        return access;
    }
    
    public func getRegisteredEndpointType(_ service: String, _ characteristic: String, accessLevel: AccessLevel) -> BluetoothData.Type? {
        let key = BluetoothEndpoint.createKey(service: service, characteristic: characteristic)
        if let endpoint = registeredEndpointTypes[accessLevel]?[key] {
            return endpoint.self
        }
        return nil
    }
    
    public func findBluetoothDevices(matching evalFunction: @escaping ((String)->Bool), completion:@escaping (([BluetoothDevice]?, Error?)->Void)) {
        BluetoothHelper.shared.scanForNearbyDevices(matching: evalFunction) {
            devices, error in
            if let error = error {
                completion(nil, error)
                return
            }
            completion(devices, nil)
        }
    }
    
    public func findBluetoothDevices(withEndpoints endpoints: [BluetoothEndpoint]?, completion:@escaping (([BluetoothDevice]?, Error?)->Void)) {
        
        var services: [String]? = nil
        if let endpoints = endpoints {
            services = endpoints.map {$0.serviceUUID}
        }
        
        BluetoothHelper.shared.scanForNearbyDevices(with: services) {
            devices, error in
            if let error = error {
                completion(nil, error)
                return
            }
            completion(devices, nil)
        }
    }
    
    public func stopScan() {
        BluetoothHelper.shared.stopScan()
    }
    
    public func connect(to device: BluetoothDevice, completion: @escaping ((Bool,Error?)->Void)) {
        BluetoothHelper.shared.connectToDevice(device: device.id) {
            connected, error in
            if error != nil {
                completion(false, BluetoothDeviceError("Device not found."))
                return
            }
            completion(connected, nil)
        }
    }
    
    public func disconnect(from device: BluetoothDevice, completion: ((Bool, Error?)->Void)?) {
        BluetoothHelper.shared.userDisconnect(device.id) {
            result, error in
            completion?(result, error)
        }
    }
    
    public func read(from endpoint: BluetoothEndpoint, on device: BluetoothDevice) {
        BluetoothHelper.shared.read(characteristic: endpoint.characteristicUUID, from: endpoint.serviceUUID, on: device.id)
    }
    
    public func write(to endpoint: BluetoothEndpoint, data: BluetoothData, on device: BluetoothDevice) {
        let access = getAccessLevels(endpoint)
        let needsResponse = access.contains(.writeWithResponse)
        let data = data.toData()
        BluetoothHelper.shared.write(data: data, characteristic: endpoint.characteristicUUID, to: endpoint.serviceUUID, on: device.id, needsResponse: needsResponse)
    }
    
    public func listen(to endpoint: BluetoothEndpoint, on device: BluetoothDevice) {
        BluetoothHelper.shared.listenFor(characteristic: endpoint.characteristicUUID, on: endpoint.serviceUUID, with: device.id)
    }
    
    public func subscribe<B:BluetoothDataSubscriber>(to endpoint: BluetoothEndpoint, subscriber: B) {
        subscribedEndpoints.updateValue(subscriber, forKey: endpoint.key)
    }
    
    //MARK: - BluetoothHelperDelegate
    func onScanResult(device: BluetoothDevice) {
        self.delegate?.onDeviceFound(device: device)
    }
    
    func onScanStateChanged(scanning: Bool) {
        delegate?.onScanStateChanged(scanning: scanning)
    }
    
    func onDataRecieved(deviceId: String, service: String, characteristic: String, data: Data, accessLevel: AccessLevel) {
        
        if let endpoint = getRegisteredEndpoint(service, characteristic),
            let type = getRegisteredEndpointType(service, characteristic, accessLevel: accessLevel) {
            
            let newValue = type.init().fromData(data: data, to: type)
            if let subscriber = subscribedEndpoints[endpoint.key] {
                subscriber._newState(deviceId: deviceId, state: newValue)
            }
            
            delegate?.onValue(for: endpoint, on: deviceId, value: newValue)
        }
    }
    
    func onDeviceConnected(deviceId: String) {
        delegate?.onDeviceConnected(deviceId: deviceId)
    }
    
    func onDeviceDisconnected(deviceId: String) {
        delegate?.onDeviceDisconnected(deviceId: deviceId)
    }
    
}

public protocol BluetoothManagerDelegate {
    func onValue(for endpoint: BluetoothEndpoint, on device: String, value: BluetoothData)
    func onDeviceFound(device: BluetoothDevice)
    func onDeviceConnected(deviceId: String)
    func onDeviceDisconnected(deviceId: String)
    func onScanStateChanged(scanning: Bool)
}

