import Network
import XCTest
@testable import ipvfoo_safari_Extension

final class DNSResolverTests: XCTestCase {
    func testPolicyPrecedencePrefersNativeIPv6OverIPv4Mapped() {
        let nativeIPv6 = DNSResolver.getPolicyEntry(for: "2001:db8::1")
        let ipv4Mapped = DNSResolver.getPolicyEntry(for: "192.0.2.1")

        XCTAssertGreaterThan(
            nativeIPv6.precedence,
            ipv4Mapped.precedence,
            "Native IPv6 should have higher precedence than IPv4-mapped addresses"
        )
    }

    func testSortAddressesByPrecedencePrefersNativeIPv6() {
        let addresses: [DNSResolver.AddressResult] = [
            .init(address: "::ffff:203.0.113.1", version: "v4"),
            .init(address: "2001:db8::1", version: "v6"),
        ]

        let sorted = DNSResolver.sortAddressesByRFC6724(addresses)
        XCTAssertEqual(
            sorted.first?.address,
            "2001:db8::1",
            "Higher precedence native IPv6 address should be chosen first"
        )
    }

    func testMapIPv4ToIPv6ProducesIPv4MappedAddress() {
        let mapped = DNSResolver.mapIPv4ToIPv6("203.0.113.5")
        XCTAssertEqual(mapped?.presentation, "::ffff:203.0.113.5")
    }

    func testMatchesPrefixWithMatchingIPv6Prefix() {
        let address = IPv6Address("2001:db8::1")!
        XCTAssertTrue(DNSResolver.matchesPrefix(address: address, prefix: "2001:db8::/32"))
        XCTAssertFalse(DNSResolver.matchesPrefix(address: address, prefix: "2001:0db9::/32"))
    }

    func testLookupDomainReturnsDirectIPv4Literal() async {
        let result = await DNSResolver.lookupDomain("192.0.2.2")
        XCTAssertEqual(result.addresses, [.init(address: "192.0.2.2", version: "v4")])
    }

    func testLookupDomainReturnsDirectIPv6Literal() async {
        let result = await DNSResolver.lookupDomain("2001:db8::2")
        XCTAssertEqual(result.addresses, [.init(address: "2001:db8::2", version: "v6")])
    }

    func testAlgorithmMatchesLiveTcpSelection() async {
        let hosts = [
            ("example.com", "dual"),
            ("ipv6.google.com", "ipv6"),
            ("akamai.com", "dual"),
            ("ipv4only.arpa", "ipv4"),
        ]

        for (host, kind) in hosts {
            let summary = await DNSResolver.lookupDomain(host)
            guard let best = summary.addresses.first else {
                XCTFail("Expected resolved addresses for \(host)")
                continue
            }

            guard let verified = summary.tcpVerifiedAddress else {
                XCTFail("Expected TCP verification for \(host)")
                continue
            }

            XCTAssertEqual(
                best.address,
                verified,
                "Best address should match TCP selection for \(host) type \(kind)"
            )
        }
    }
}