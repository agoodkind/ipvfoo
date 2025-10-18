//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Alex Goodkind on 10/17/25.
//

import Network
import os.log
import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func lookupDomain(_ domain: String) -> String? {
        os_log(.default, "[DNS] Starting lookup for: %{public}@", domain)
        let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()
        os_log(.default, "[DNS] CFHost created")

        var error = CFStreamError()
        let started = CFHostStartInfoResolution(host, .addresses, &error)
        os_log(.default, "[DNS] Resolution started: %{public}d, error domain: %{public}d, error code: %{public}d", started, error.domain, error.error)

        var success: DarwinBoolean = false
        guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?, success.boolValue else {
            os_log(.error, "[DNS] CFHostGetAddressing returned nil or failed, success: %{public}d", success.boolValue)
            return nil
        }

        os_log(.default, "[DNS] Got %{public}d addresses", addresses.count)

        for (index, element) in addresses.enumerated() {
            guard let theAddress = element as? NSData else { continue }
            os_log(.default, "[DNS] Processing address %{public}d, length: %{public}d", index, theAddress.length)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0
            {
                let ip = String(cString: hostname)
                os_log(.default, "[DNS] Resolved to: %{public}@", ip)
                return ip
            } else {
                os_log(.error, "[DNS] getnameinfo failed for address %{public}d", index)
            }
        }

        os_log(.error, "[DNS] No valid addresses found")
        return nil
    }

    func beginRequest(with context: NSExtensionContext) {
        os_log(.default, "[Begin] Handling new extension request")
        let request = context.inputItems.first as? NSExtensionItem
        os_log(.default, "[Begin] Extracted first input item: %{public}@", String(describing: request))

        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }
        os_log(.default, "[Begin] Profile: %{public}@", profile?.uuidString ?? "none")

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }
        os_log(.default, "[Begin] Raw message payload: %{public}@", String(describing: message))

        os_log(.default, "[Begin] Parsing message for command routing")

        var responseMessage: [String: Any] = [:]

        if let messageDict = message as? [String: Any],
           let cmd = messageDict["cmd"] as? String,
           cmd == "lookup",
           let domain = messageDict["domain"] as? String
        {
            os_log(.default, "[Lookup] Performing DNS lookup for: %{public}@", domain)
            if let ip = lookupDomain(domain) {
                os_log(.default, "[Lookup] Lookup success: %{public}@ -> %{public}@", domain, ip)
                responseMessage = ["ip": ip]
            } else {
                os_log(.error, "[Lookup] Lookup failed for: %{public}@", domain)
                responseMessage = ["error": "DNS lookup failed"]
            }
        } else {
            os_log(.default, "[Begin] Echoing message back to sender")
            responseMessage = ["echo": message ?? ""]
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: responseMessage]
        } else {
            response.userInfo = ["message": responseMessage]
        }

        os_log(.default, "[Begin] Completing request with response message")
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
