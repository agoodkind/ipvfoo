import Darwin
import Foundation
import Network

/// Resolves hostnames and orders candidate IP addresses using RFC 6724 while
/// taking the host machine's network capabilities into account.
enum DNSResolver {
    /// Attempt an actual TCP connection to confirm which address the system ultimately uses.
    static func verifyTcpConnection(
        domain: String,
        port: UInt16,
        logger: ((String) -> Void)? = nil
    ) async -> String? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            logger?("[DNS] TCP verification invalid port=\(port)")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(domain),
                port: nwPort,
                using: .tcp
            )
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
                       case let .hostPort(host, _) = endpoint
                    {
                        switch host {
                        case let .ipv4(addr):
                            ip = addr.debugDescription
                        case let .ipv6(addr):
                            ip = addr.debugDescription
                        default:
                            break
                        }
                    }
                    logger?(
                        "[DNS] TCP ready remote=\(ip ?? "unknown") domain=\(domain)"
                    )
                    connection.cancel()
                    finish(ip)
                case let .failed(error):
                    logger?(
                        "[DNS] TCP verification failed domain=\(domain) error=\(error.localizedDescription)"
                    )
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
}
