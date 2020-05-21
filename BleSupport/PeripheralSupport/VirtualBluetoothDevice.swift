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
import CoreBluetooth

open class VirtualBluetoothDevice: NSObject, CBPeripheralManagerDelegate {
        
    private var peripheralManager : CBPeripheralManager!
    private var bluetoothManager : BluetoothManager!
        
    private var services = [String: CBMutableService]()
    private var centrals = [String: [CBCentral]]()
    
    public var delegate: VirtualBluetoothDeviceDelegate? = nil
    
    public init(bluetoothManager: BluetoothManager) {
        super.init()
        self.bluetoothManager = bluetoothManager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    private func setup() {
        
        let endpoints = bluetoothManager.allRegisteredEndpoints()
        for endpoint in endpoints {
            let service = endpoint.serviceUUID

            let cbService = services[service] ?? CBMutableService(type: CBUUID(string: service), primary: true)

            let characteristic = endpoint.characteristicUUID
            let properties = getAccessProperties(service, characteristic)

            let cbCharacteristic = CBMutableCharacteristic(type: CBUUID(string: characteristic), properties: properties, value: nil, permissions: [.readable, .writeable])

            cbService.characteristics = cbService.characteristics ?? []
            cbService.characteristics?.append(cbCharacteristic)

            services.updateValue(cbService, forKey: service)
        }

        peripheralManager.removeAllServices()
        for service in Array(services.values) {
            print("adding service \(service.uuid.uuidString)")
            peripheralManager.add(service)
        }

        delegate?.onDeviceReady()
    }
    
    private func getAccessProperties(_ service: String, _ characteristic: String) -> CBCharacteristicProperties {
        let access = bluetoothManager.getAccessLevels(service, characteristic)
        var properties: CBCharacteristicProperties = []
        
        if access.contains(.read) { properties.update(with: .read)}
        if access.contains(.writeWithResponse) { properties.update(with: .write)}
        if access.contains(.writeNoResponse) { properties.update(with: .writeWithoutResponse)}
        if access.contains(.notify) { properties.update(with: .notify)}
        print("\(characteristic) \(access)")
        return properties
    }
    
    public func startAdvertising(name: String, services: [String]? = nil) {
        let advertisedServices = [CBUUID]()
            //[CBUUID(string:"041BF001-D077-4138-9369-CC25C7BFF7ED")]
        //Array(self.services.values).filter { services?.contains($0.uuid.uuidString) ?? false }
        peripheralManager.startAdvertising([CBAdvertisementDataLocalNameKey : name, CBAdvertisementDataServiceUUIDsKey:advertisedServices])
    }
    
    public func stopAdvertisting() {
        peripheralManager.stopAdvertising()
    }
    
    public func getBluetoothManager() -> BluetoothManager {
        return self.bluetoothManager
    }
    
    public func updateValue(endpoint: BluetoothEndpoint, value: BluetoothData) {
        guard let service = services[endpoint.serviceUUID] else { return; }
        guard let cbCharacteristic = service.characteristics?.first(where: { $0.uuid.uuidString == endpoint.characteristicUUID } ) as? CBMutableCharacteristic else { return; }
        
        let data = value.toData()
        let subscribers = centrals[endpoint.characteristicUUID]
        
        peripheralManager.updateValue(data, for: cbCharacteristic, onSubscribedCentrals: subscribers)
    }
    
    //MARK: - CBPeripheralManagerDelegate
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Advertising errors: \(error?.localizedDescription ?? "None")")
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .unknown:
            delegate?.onStateChange(state: .unknown)
        case .unsupported:
            delegate?.onStateChange(state: .unsupported)
        case .unauthorized:
            delegate?.onStateChange(state: .unauthorized)
        case .resetting:
            delegate?.onStateChange(state: .resetting)
        case .poweredOff:
            delegate?.onStateChange(state: .poweredOff)
        case .poweredOn:
            delegate?.onStateChange(state: .poweredOn)
            setup()
        @unknown default:
            print("Unknown State")
        }
    }
        
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if let request = requests.first, let data = request.value {
            let service = request.characteristic.service.uuid.uuidString
            let characteristic = request.characteristic.uuid.uuidString
            if let endpoint = bluetoothManager.getRegisteredEndpoint(service, characteristic),
                let type = bluetoothManager.getRegisteredEndpointType(service, characteristic, accessLevel: .writeWithResponse) {
                let bluetoothData = type.init().fromData(data: data, to: type)
                delegate?.onWrite(endpoint: endpoint, data: bluetoothData)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let service = request.characteristic.service.uuid.uuidString
        let characteristic = request.characteristic.uuid.uuidString
        if let endpoint = bluetoothManager.getRegisteredEndpoint(service, characteristic) {
            delegate?.onRead(endpoint: endpoint) {
                bluetoothData in
                request.value = bluetoothData.toData()
            }
        }
        peripheral.respond(to: request, withResult: .success)
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        centrals[characteristic.uuid.uuidString] = centrals[characteristic.uuid.uuidString] ?? []
        centrals[characteristic.uuid.uuidString]?.append(central)
        print("didSubscribeTo",characteristic.uuid.uuidString)
        print("didSubscribeTo centrals",centrals)
    }
    
    public func  peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard let index = centrals[characteristic.uuid.uuidString]?.firstIndex(of: central) else { return; }
        centrals[characteristic.uuid.uuidString]?.remove(at: index)
    }
}

public enum DeviceState {
    case unknown
    case unsupported
    case unauthorized
    case resetting
    case poweredOff
    case poweredOn
}
