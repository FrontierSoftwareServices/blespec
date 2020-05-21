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

extension Data {
    
    public func getUInt8(_ endianess: Endianess = .big, at index: Int) -> UInt8? {
        let range: Range<Data.Index> = index..<index+MemoryLayout<UInt8>.size
        if self.count >= range.endIndex {
            var value : UInt8 = 0
            copyBytes(to: &value, from: range)
            if endianess == .big {
                return UInt8(bigEndian: value)
            }
            return UInt8(littleEndian: value)
        }
        
        return nil
    }
    
    public func getUInt16(_ endianess: Endianess = .big, at index: Int) -> UInt16?{
        let range: Range<Data.Index> = index..<index+MemoryLayout<UInt16>.size
        if self.count >= range.endIndex {
            var value : UInt16 = 0
            let subdata = self.subdata(in: range)
            let array = subdata.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0, count: subdata.count))
            }
            let data = NSData(bytes: array, length: subdata.count)
            data.getBytes(&value, length: subdata.count)
            value = UInt16(bigEndian: value)
            if endianess == .big {
                return UInt16(bigEndian: value)
            }
            return UInt16(littleEndian: value)
        }
        
        return nil
    }
    
    public func getInt16(_ endianess: Endianess = .big, at index: Int) -> Int16?{
        let range: Range<Data.Index> = index..<index+MemoryLayout<Int16>.size
        if self.count >= range.endIndex {
            var value : Int16 = 0
            let subdata = self.subdata(in: range)
            let array = subdata.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0, count: subdata.count))
            }
            let data = NSData(bytes: array, length: subdata.count)
            data.getBytes(&value, length: subdata.count)
            //value = Int16(bigEndian: value)
            if endianess == .big {
                return Int16(bigEndian: value)
            }
            return Int16(littleEndian: value)
        }
        
        return nil
    }
    
    public func getUInt32(_ endianess: Endianess = .big, at index: Int) -> UInt32?{
        let range: Range<Data.Index> = index..<index+MemoryLayout<UInt32>.size
        if self.count >= range.endIndex {
            var value : UInt32 = 0
            let subdata = self.subdata(in: range)
            let array = subdata.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0, count: subdata.count))
            }
            let data = NSData(bytes: array, length: subdata.count)
            data.getBytes(&value, length: subdata.count)
            value = UInt32(bigEndian: value)
            if endianess == .big {
                return UInt32(bigEndian: value)
            }
            return UInt32(littleEndian: value)
        }
        
        return nil
    }
    
    public func subdata(in range: ClosedRange<Index>) -> Data {
        let range_upperbound = range.upperBound + 1
        let upperbound = range_upperbound <= self.count ? range_upperbound : self.count
        return subdata(in: range.lowerBound ..< upperbound )
    }
    
    public var uuid: NSUUID? {
        get {
            var bytes = [UInt8](repeating: 0, count: self.count)
            self.copyBytes(to:&bytes, count: self.count * MemoryLayout<UInt32>.size)
            return NSUUID(uuidBytes: bytes)
        }
    }
    public var stringASCII: String? {
        get {
            return NSString(data: self, encoding: String.Encoding.ascii.rawValue) as String?
        }
    }
    
    public var stringUTF8: String? {
        get {
            return NSString(data: self, encoding: String.Encoding.utf8.rawValue) as String?
        }
    }
    
    public struct HexEncodingOptions: OptionSet {
        public var rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    public func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
    
}

public enum Endianess {
    case big
    case little
}

