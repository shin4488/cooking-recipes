import Foundation

/// 接続先が公開IPアドレスかを判定する。社内ネットワークや端末内への接続を防ぐ
public enum PublicAddress {
    public static func isPublic(_ address: String) -> Bool {
        var text = address
        if text.hasPrefix("[") && text.hasSuffix("]") { text = String(text.dropFirst().dropLast()) }
        if let zone = text.firstIndex(of: "%") { text = String(text[..<zone]) }
        if let octets = ipv4Octets(text) { return isPublicIPv4(octets) }
        if let bytes = ipv6Bytes(text) { return isPublicIPv6(bytes) }
        return false
    }

    static func ipv4Octets(_ text: String) -> [UInt8]? {
        var address = in_addr()
        guard inet_pton(AF_INET, text, &address) == 1 else { return nil }
        return withUnsafeBytes(of: address) { Array($0) }
    }

    static func ipv6Bytes(_ text: String) -> [UInt8]? {
        var address = in6_addr()
        guard inet_pton(AF_INET6, text, &address) == 1 else { return nil }
        return withUnsafeBytes(of: address) { Array($0) }
    }

    static func isPublicIPv4(_ octets: [UInt8]) -> Bool {
        let a = octets[0], b = octets[1], c = octets[2]
        switch a {
        case 0, 10, 127: return false
        case 100 where (64...127).contains(b): return false
        case 169 where b == 254: return false
        case 172 where (16...31).contains(b): return false
        case 192 where b == 168: return false
        case 192 where b == 0 && (c == 0 || c == 2): return false
        case 198 where b == 18 || b == 19: return false
        case 198 where b == 51 && c == 100: return false
        case 203 where b == 0 && c == 113: return false
        case 224...255: return false
        default: return true
        }
    }

    static func isPublicIPv6(_ bytes: [UInt8]) -> Bool {
        // IPv4射影アドレス（::ffff:0:0/96）と NAT64（64:ff9b::/96）は、埋め込まれたIPv4で判定する
        if bytes[0..<10].allSatisfy({ $0 == 0 }) && bytes[10] == 0xff && bytes[11] == 0xff {
            return isPublicIPv4(Array(bytes[12..<16]))
        }
        if bytes[0..<12] == [0x00, 0x64, 0xff, 0x9b, 0, 0, 0, 0, 0, 0, 0, 0] {
            return isPublicIPv4(Array(bytes[12..<16]))
        }
        // グローバルユニキャスト（2000::/3）のうち、文書用（2001:db8::/32）を除く
        guard bytes[0] & 0xe0 == 0x20 else { return false }
        return !(bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8)
    }
}
