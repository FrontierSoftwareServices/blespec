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

@objcMembers
open class BluetoothData: NSObject, Initializable {
    
    private(set) public var rawValue: Data? = nil
    
    public required override init() {
        super.init()
    }
    
    open override var description: String {
        let props = propertyDescriptions()
        
        var result = [String]()
        for key in props.keys.sorted() {
            result.append("\(key):\(props[key]!)")
        }
        return result.joined(separator: ",")
    }
    
    open func dataMap() -> Dictionary<String,Packet> {
        return [:]
    }
    
    public var accessLevels: [AccessLevel] = [.read, .writeWithResponse, .notify]
    
    var dataSortedByRange: [(String,Packet)] {
        return dataMap().sorted {
            $0.1.range().startIndex < $1.1.range().startIndex
        }
    }
    
    func getValue(_ packet: Packet, _ data: Data) -> Any? {
        switch packet {
        case .uint8:
            return data.getUInt8(packet.endianess(), at: 0)
        case .uint16:
            return data.getUInt16(packet.endianess(), at: 0)
        case .int16:
            return data.getInt16(packet.endianess(), at: 0)
        case .uint32:
            return data.getUInt32(packet.endianess(), at: 0)
        case .float:
            return 0
        case .int:
            return 0
        case .string:
            return data.stringASCII
        case .uuid:
            return data.uuid
        }
        
    }
    
    open func fromData(data: Data, to: BluetoothData.Type) -> BluetoothData {
        
        let newInstance = to.self.init()
        newInstance.rawValue = data
        let packets = dataMap()
        
        let mirror = Mirror(reflecting: newInstance)
        for (name, _) in mirror.children {
            guard let name = name else { continue }
            guard let prop = packets[name] else { continue }
            let range = prop.range()
            let subData = data.subdata(in: range)
            if let newValue = getValue(prop, subData) {
                do {
                    try? newInstance.setValue(newValue, forKey: name)
                } catch {
                    print("Unable to set value \(name) on \(to)")
                }
            }
        }
        
        return newInstance
    }
    
    open func toData() -> Data {
        
        let mirror = Mirror(reflecting: self)
        let currentProperties = mirror.toDictionary()
        
        func getData(prop: Packet,  value: Any) -> Data {
            switch prop {
            case .uint8:
                return value is UInt8 ? (value as! UInt8).data : Data()
            case .uint16:
                return value is UInt16 ? (value as! UInt16).data : Data()
            case .int16:
                return value is Int16 ? (value as! Int16).data : Data()
            case .uint32:
                return value is UInt32 ? (value as! UInt32).data : Data()
            case .string:
                return value is String ? (value as! String).data(using: String.Encoding.ascii)! : Data()
            case .uuid:
                return value is UUID ? (value as! UUID).data : Data()
            default:
                return Data()
            }
        }
        
        func getValue(forKey key: String) -> Any? {
            return currentProperties[key]
        }
        
        var data = Data()
        for (name, prop) in dataSortedByRange {
            guard let value = getValue(forKey: name) else { continue; }
            let valueAsData = getData(prop: prop, value: value)
            data.append(valueAsData)
        }
        
        return data
    }
    
    open func getValueDescription(for property: String, rawValue: Any?) -> String {
        if let val = rawValue {
            return "\(String(describing: val))"
        }
        return "Not set"
    }
        
    public func propertyDescriptions() -> [String: String] {
        let mirror = Mirror(reflecting: self)
        let currentProperties = mirror.toDictionary()
        
        func getValue(forKey key: String) -> Any? {
            return currentProperties[key]
        }
        
        var readable = [String:String]()
        for (name, _) in dataSortedByRange {
            guard let value = getValue(forKey: name) else { continue; }
            let valueDescription = getValueDescription(for: name, rawValue: value)
            readable[name] = valueDescription
        }
        
        return readable
    }
    
    public enum Packet {
        
        public func range() -> ClosedRange<Int> {
            switch self {
            case .uint8(let range, _):
                return range
            case .uint16(let range, _):
                return range
            case .int16(let range, _):
                return range
            case .uint32(let range, _):
                return range
            case .float(let range, _):
                return range
            case .int(let range, _):
                return range
            case .string(let range, _):
                return range
            case .uuid(let range, _):
                return range
            }
        }
        
        public func endianess() -> Endianess {
            switch self {
            case .uint8( _, let endianess):
                return endianess
            case .uint16( _, let endianess):
                return endianess
            case .int16( _, let endianess):
                return endianess
            case .uint32( _, let endianess):
                return endianess
            case .float( _, let endianess):
                return endianess
            case .int( _, let endianess):
                return endianess
            case .string( _):
                return .little
            case .uuid( _):
                return .little
            }
        }
        
        case uint8(range:ClosedRange<Int>, _ endian: Endianess)
        case uint16(range:ClosedRange<Int>, _ endian: Endianess)
        case int16(range:ClosedRange<Int>, _ endian: Endianess)
        case uint32(range:ClosedRange<Int>, _ endian: Endianess)
        case float(range:ClosedRange<Int>, _ endian: Endianess)
        case int(range:ClosedRange<Int>, _ endian: Endianess)
        case string(range:ClosedRange<Int>, _ endian: Endianess)
        case uuid(range:ClosedRange<Int>, _ endian: Endianess)
        
    }
    
}

extension Mirror {

    func toDictionary() -> [String: AnyObject] {
        var dict = [String: AnyObject]()

        // Properties of this instance:
        for attr in self.children {
            if let propertyName = attr.label {
                dict[propertyName] = attr.value as AnyObject
            }
        }

        // Add properties of superclass:
        if let parent = self.superclassMirror {
            for (propertyName, value) in parent.toDictionary() {
                dict[propertyName] = value
            }
        }

        return dict
    }
}

protocol Initializable {
    init()
}

public protocol AnyDataSubscriber: class {
    // swiftlint:disable:next identifier_name
    func _newState(deviceId: String, state: Any)
}

public protocol BluetoothDataSubscriber: AnyDataSubscriber {
    associatedtype BluetoothDataSubscriberType
    
    func newState(deviceId: String, state: BluetoothDataSubscriberType)
}

extension BluetoothDataSubscriber {
    // swiftlint:disable:next identifier_name
    public func _newState(deviceId: String, state: Any) {
        if let typedState = state as? BluetoothDataSubscriberType {
            newState(deviceId: deviceId, state: typedState)
        }
    }
}

public enum AccessLevel: Int, Codable, CaseIterable {
   case read = 0
   case writeWithResponse = 1
   case writeNoResponse = 2
   case notify = 3
}

