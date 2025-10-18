import Darwin
import Foundation
import Network

/// Resolves hostnames and orders candidate IP addresses using RFC 6724 while
/// taking the host machine's network capabilities into account.
struct DNSResolver {
    /// A resolved address annotated with the IP family.
    struct AddressResult: Equatable {
        let address: String
        let version: String
    }

    /// Returned summary for a lookup including ordered addresses and the
    /// address actually used for a verification TCP connection (if performed).
    struct LookupSummary: Equatable {
        let addresses: [AddressResult]
        let tcpVerifiedAddress: String?
    }

    struct PolicyEntry {
        let prefix: String
        let precedence: Int
        let label: Int
    }

    /// Summary of local interface capabilities. Used to bias precedence so we
    /// avoid preferring IPv6 addresses that the local machine cannot reach.
    struct LocalAddressState {
        let hasIPv4: Bool
        let hasGlobalIPv6: Bool
        let hasULAIPv6: Bool
    }

    // RFC 6724 Section 2.1 - Default Policy Table with additional ordering tweaks
    // so IPv4 outranks ULA-only IPv6 when no global IPv6 is available.
    static let policyTable: [PolicyEntry] = [
        PolicyEntry(prefix: "::1/128", precedence: 60, label: 0),  // Loopback
        PolicyEntry(prefix: "::/0", precedence: 50, label: 1),  // Default IPv6 (GUA)
        PolicyEntry(prefix: "::ffff:0:0/96", precedence: 45, label: 4),  // IPv4-mapped (public IPv4)
        PolicyEntry(prefix: "fc00::/7", precedence: 40, label: 13),  // ULA
        PolicyEntry(prefix: "2001::/32", precedence: 30, label: 5),  // Teredo
        PolicyEntry(prefix: "2002::/16", precedence: 25, label: 2),  // 6to4
        PolicyEntry(prefix: "::/96", precedence: 15, label: 3),  // IPv4-compatible (deprecated)
        PolicyEntry(prefix: "fec0::/10", precedence: 10, label: 11),  // Site-local (deprecated)
        PolicyEntry(prefix: "3ffe::/16", precedence: 1, label: 12),  // 6bone (deprecated)
    ]

    // Perform DNS lookup - returns addresses with version (v4/v6)
    static func lookupDomain(_ domain: String, logger: ((String) -> Void)? = nil) async -> LookupSummary {
        logger?("[DNS] lookupDomain start domain=\(domain)")

        // Domains that are already literal IP addresses bypass DNS.
        if IPv4Address(domain) != nil {
            return LookupSummary(addresses: [AddressResult(address: domain, version: "v4")], tcpVerifiedAddress: nil)
        }
        if IPv6Address(domain) != nil {
            return LookupSummary(addresses: [AddressResult(address: domain, version: "v6")], tcpVerifiedAddress: nil)
        }

        let addresses = await resolveHostname(domain, logger: logger)
        let localState = localAddressState(logger: logger)
        let sorted = sortAddressesByRFC6724(addresses, localState: localState, logger: logger)
        logger?("[DNS] Applied RFC 6724 address selection count=\(sorted.count)")
        for (index, entry) in sorted.enumerated() {
            logger?("[DNS] result[\(index)] address=\(entry.address) version=\(entry.version)")
        }

        // Opportunistically open a TCP connection so we can log which address the
        // OS ultimately uses. This helps debug precedence mismatches.
        var verifiedAddress: String?
        if let best = sorted.first {
            verifiedAddress = await verifyTcpConnection(domain: domain, port: 443, logger: logger)
            if let verified = verifiedAddress {
                let match = verified == best.address
                logger?("[DNS] TCP verification remoteAddress=\(verified) matchesBest=\(match)")
            } else {
                logger?("[DNS] TCP verification unavailable for domain=\(domain)")
            }
        }
        return LookupSummary(addresses: sorted, tcpVerifiedAddress: verifiedAddress)
    }

    static func resolveHostname(_ hostname: String, logger: ((String) -> Void)? = nil) async -> [AddressResult] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM
                hints.ai_flags = AI_ADDRCONFIG

                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(hostname, nil, &hints, &result)

                guard status == 0, let head = result else {
                    let errStr = String(cString: gai_strerror(status))
                    logger?("[DNS] getaddrinfo failed domain=\(hostname) error=\(status) message=\(errStr)")
                    continuation.resume(returning: [])
                    return
                }

                defer { freeaddrinfo(head) }

                var addresses: [AddressResult] = []
                var current: UnsafeMutablePointer<addrinfo>? = head

                while let info = current {
                    defer { current = info.pointee.ai_next }

                    guard let addr = info.pointee.ai_addr else { continue }

                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let addrLen = socklen_t(info.pointee.ai_addrlen)

                    guard getnameinfo(addr, addrLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                        logger?("[DNS] getnameinfo failed index addressFamily=\(info.pointee.ai_family)")
                        continue
                    }

                    let version = info.pointee.ai_family == AF_INET ? "v4" : "v6"
                    let stringAddress = String(cString: host)
                    logger?("[DNS] resolved raw address=\(stringAddress) version=\(version)")
                    addresses.append(AddressResult(address: stringAddress, version: version))
                }

                logger?("[DNS] resolveHostname finished domain=\(hostname) count=\(addresses.count)")
                for (idx, entry) in addresses.enumerated() {
                    logger?("[DNS] resolveHostname[\(idx)] address=\(entry.address) version=\(entry.version)")
                }
                let sorted = sortAddressesByRFC6724(addresses, localState: localAddressState(logger: logger), logger: logger)
                logger?("[DNS] resolveHostname sorted count=\(sorted.count)")
                continuation.resume(returning: sorted)
            }
        }
    }

    // MARK: - RFC 6724 Address Selection

    /// Compute precedence/label for an address after applying RFC 6724 default
    /// policy table and adjusting based on local connectivity.
    static func getPolicyEntry(for address: String, localState: LocalAddressState, logger: ((String) -> Void)? = nil) -> (precedence: Int, label: Int) {
        guard let addr = IPv6Address(address) ?? mapIPv4ToIPv6(address) else {
            return (precedence: 40, label: 1)
        }

        var matchedEntry: PolicyEntry?
        for entry in policyTable {
            if matchesPrefix(address: addr, prefix: entry.prefix) {
                matchedEntry = entry
                break
            }
        }

        var precedence = matchedEntry?.precedence ?? 40
        let label = matchedEntry?.label ?? 1

        if matchesPrefix(address: addr, prefix: "::ffff:0:0/96") {
            if !localState.hasIPv4 {
                precedence = 0
                logger?("[DNS] policy adjust IPv4 disabled address=\(address)")
            } else if !localState.hasGlobalIPv6 && localState.hasULAIPv6 {
                precedence += 5
                logger?("[DNS] policy boost IPv4 due to ULA-only environment address=\(address)")
            }
        } else if matchesPrefix(address: addr, prefix: "::/0") {
            if !localState.hasGlobalIPv6 {
                precedence -= 15
                logger?("[DNS] policy penalize global IPv6 (no global source) address=\(address)")
            }
        } else if matchesPrefix(address: addr, prefix: "fc00::/7") {
            if !localState.hasULAIPv6 {
                precedence = 0
                logger?("[DNS] policy drop ULA (not available) address=\(address)")
            } else if localState.hasIPv4 && !localState.hasGlobalIPv6 {
                precedence -= 5
                logger?("[DNS] policy penalize ULA vs IPv4 address=\(address)")
            }
        }

        logger?("[DNS] policy result address=\(address) precedence=\(precedence) label=\(label)")
        return (precedence: max(precedence, 0), label: label)
    }

    static func mapIPv4ToIPv6(_ address: String) -> IPv6Address? {
        guard let ipv4 = IPv4Address(address) else { return nil }
        return IPv6Address("::ffff:\(ipv4)")
    }

    static func matchesPrefix(address: IPv6Address, prefix: String) -> Bool {
        let components = prefix.split(separator: "/")
        guard components.count == 2,
              let prefixAddr = IPv6Address(String(components[0])),
              let prefixLen = Int(components[1])
        else { return false }

        let addrBytes = address.rawValue
        let prefixBytes = prefixAddr.rawValue

        let fullBytes = prefixLen / 8
        let remainingBits = prefixLen % 8

        for i in 0..<fullBytes {
            if addrBytes[i] != prefixBytes[i] { return false }
        }

        if remainingBits > 0 {
            let mask = UInt8(0xFF << (8 - remainingBits))
            if (addrBytes[fullBytes] & mask) != (prefixBytes[fullBytes] & mask) {
                return false
            }
        }

        return true
    }

    /// Sort the set of candidate addresses using RFC 6724 rules with local link awareness.
    static func sortAddressesByRFC6724(_ addresses: [AddressResult], localState: LocalAddressState, logger: ((String) -> Void)? = nil) -> [AddressResult] {
        addresses.sorted { lhs, rhs in
            let policy1 = getPolicyEntry(for: lhs.address, localState: localState, logger: logger)
            let policy2 = getPolicyEntry(for: rhs.address, localState: localState, logger: logger)

            logger?("[DNS] sort compare lhs=\(lhs.address) prec=\(policy1.precedence) label=\(policy1.label) rhs=\(rhs.address) prec=\(policy2.precedence) label=\(policy2.label)")

            if policy1.label != policy2.label {
                return policy1.label < policy2.label
            }

            if policy1.precedence != policy2.precedence {
                return policy1.precedence > policy2.precedence
            }

            let isNative1 = IPv6Address(lhs.address) != nil && !lhs.address.contains("::ffff:")
            let isNative2 = IPv6Address(rhs.address) != nil && !rhs.address.contains("::ffff:")

            if isNative1 != isNative2 {
                return isNative1
            }

            return false
        }
    }

    /// Attempt an actual TCP connection to confirm which address the system ultimately uses.
    /// Helps validate ordering/logging, but is best-effort only.
    static func verifyTcpConnection(domain: String, port: UInt16, logger: ((String) -> Void)? = nil) async -> String? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            logger?("[DNS] TCP verification invalid port=\(port)")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(domain), port: nwPort, using: .tcp)
            var resumed = false

            @Sendable func finish(_ value: String?) {
                if !resumed {
                    resumed = true
                    continuation.resume(returning: value)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var ip: String?
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case let .hostPort(host, _) = endpoint {
                        switch host {
                        case let .ipv4(addr):
                            ip = addr.debugDescription
                        case let .ipv6(addr):
                            ip = addr.debugDescription
                        default:
                            break
                        }
                    }
                    logger?("[DNS] TCP ready remote=\(ip ?? "unknown") domain=\(domain)")
                    connection.cancel()
                    finish(ip)
                case .failed(let error):
                    logger?("[DNS] TCP verification failed domain=\(domain) error=\(error.localizedDescription)")
                    connection.cancel()
                    finish(nil)
                case .cancelled:
                    finish(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Inspect local interfaces using getifaddrs to detect whether the host has
    /// routable IPv4, global IPv6, or ULA-only IPv6 connectivity. Link-local
    /// addresses are ignored because they cannot reach external destinations.
    static func localAddressState(logger: ((String) -> Void)? = nil) -> LocalAddressState {
        var hasIPv4 = false
        var hasGlobalIPv6 = false
        var hasULAIPv6 = false

        var pointer: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&pointer) == 0, let first = pointer {
            var current: UnsafeMutablePointer<ifaddrs>? = first
            while let iface = current {
                defer { current = iface.pointee.ifa_next }

                guard let addr = iface.pointee.ifa_addr else { continue }
                switch Int32(addr.pointee.sa_family) {
                case AF_INET:
                    hasIPv4 = true
                case AF_INET6:
                    let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                    var address = sin6.sin6_addr
                    let bytes = withUnsafeBytes(of: &address) { Array($0) }

                    // Ignore link-local addresses (fe80::/10) and scoped entries.
                    if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) || sin6.sin6_scope_id != 0 {
                        continue
                    }

                    if (bytes[0] & 0xE0) == 0x20 {
                        hasGlobalIPv6 = true
                    } else if (bytes[0] & 0xFE) == 0xFC {
                        hasULAIPv6 = true
                    }
                default:
                    break
                }
            }
            freeifaddrs(first)
        }

        logger?("[DNS] Local address state: IPv4=\(hasIPv4) IPv6Global=\(hasGlobalIPv6) IPv6ULA=\(hasULAIPv6)")
        return LocalAddressState(hasIPv4: hasIPv4, hasGlobalIPv6: hasGlobalIPv6, hasULAIPv6: hasULAIPv6)
    }
}

