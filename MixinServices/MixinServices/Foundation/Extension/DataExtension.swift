import Foundation

public extension Data {
    
    var bytes : [UInt8] {
        return [UInt8](self)
    }
    
    init?(withNumberOfSecuredRandomBytes count: Int) {
        guard let bytes = malloc(count) else {
            return nil
        }
        let status = SecRandomCopyBytes(kSecRandomDefault, count, bytes)
        guard status == errSecSuccess else {
            return nil
        }
        self.init(bytesNoCopy: bytes, count: count, deallocator: .free)
    }
    
    init?(base64URLEncoded string: String) {
        var str = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if string.count % 4 != 0 {
            str.append(String(repeating: "=", count: 4 - string.count % 4))
        }
        self.init(base64Encoded: str)
    }
    
    func toHexString() -> String {
        return map { String(format: "%02.2hhx", $0) }.joined()
    }

    func toString() -> String {
        return String(data: self, encoding: .utf8)!
    }
    
    // Avoid potential timing attacks
    func isEqualToDataInConstantTime(_ another: Data) -> Bool {
        guard self.count == another.count else {
            return false
        }
        var isEqual = true
        for i in 0..<count {
            isEqual = isEqual && (self[i] == another[i])
        }
        return isEqual
    }
    
    func base64UrlEncodedString() -> String {
        var str = base64EncodedString()
        str = str.replacingOccurrences(of: "+", with: "-")
        str = str.replacingOccurrences(of: "/", with: "_")
        str = str.replacingOccurrences(of: "=", with: "")
        return str
    }
    
    @inlinable func withUnsafeUInt8Pointer<ResultType>(_ body: (UnsafePointer<UInt8>?) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeBytes({ (buffer) -> ResultType in
            let ptr = buffer.bindMemory(to: UInt8.self).baseAddress
            return try body(ptr)
        })
    }
    
    @inlinable mutating func withUnsafeMutableUInt8Pointer<ResultType>(_ body: (UnsafeMutablePointer<UInt8>?) throws -> ResultType) rethrows -> ResultType {
        return try withUnsafeMutableBytes({ (buffer) -> ResultType in
            let ptr = buffer.bindMemory(to: UInt8.self).baseAddress
            return try body(ptr)
        })
    }
    
}

public extension Optional where Wrapped == Data {
    
    var isNilOrEmpty: Bool {
        switch self {
        case .some(let value):
            return value.isEmpty
        case .none:
            return true
        }
    }
    
}
