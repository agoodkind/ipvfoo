import os.log
import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func lookupDomain(_ domain: String) -> [[String: String]] {
        os_log(.debug, "[DNS] Looking up: %{public}@", domain)
        
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_ADDRCONFIG
        
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(domain, nil, &hints, &result)
        guard status == 0, let head = result else {
            let errStr = String(cString: gai_strerror(status))
            os_log(.error, "[DNS] Failed: %{public}d (%{public}@)", status, errStr)
            return []
        }
        defer { freeaddrinfo(head) }
        
        var addresses: [[String: String]] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = head
        while let current = cursor {
            if let addr = current.pointee.ai_addr {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(current.pointee.ai_addrlen), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let version = current.pointee.ai_family == AF_INET ? "v4" : "v6"
                    let address = String(cString: host)
                    os_log(.debug, "[DNS] Found %{public}@ (%{public}@)", address, version)
                    addresses.append(["address": address, "version": version])
                }
            }
            cursor = current.pointee.ai_next
        }
        
        os_log(.debug, "[DNS] Resolved %{public}d addresses", addresses.count)
        return addresses
    }
    
    func beginRequest(with context: NSExtensionContext) {
        os_log(.debug, "[Request] Received")
        
        guard let request = context.inputItems.first as? NSExtensionItem else {
            os_log(.error, "[Request] No input item")
            return
        }
        
        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request.userInfo?[SFExtensionMessageKey]
        } else {
            message = request.userInfo?["message"]
        }
        
        os_log(.debug, "[Request] Message: %{public}@", String(describing: message))
        
        let responseMessage: [String: Any]
        if let messageDict = message as? [String: Any],
           messageDict["cmd"] as? String == "lookup",
           let domain = messageDict["domain"] as? String {
            let addresses = lookupDomain(domain)
            if addresses.isEmpty {
                os_log(.error, "[Request] Lookup failed for %{public}@", domain)
                responseMessage = ["error": "DNS lookup failed"]
            } else {
                os_log(.debug, "[Request] Lookup succeeded for %{public}@", domain)
                responseMessage = ["addresses": addresses]
            }
        } else {
            os_log(.debug, "[Request] Echoing message")
            responseMessage = ["echo": message ?? ""]
        }
        
        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: responseMessage]
        } else {
            response.userInfo = ["message": responseMessage]
        }
        
        os_log(.debug, "[Request] Completing")
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
