import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    // Main entry point for extension requests
    func beginRequest(with context: NSExtensionContext) {
        os_log(.debug, "[Request] beginRequest start")

        guard let request = context.inputItems.first as? NSExtensionItem else {
            os_log(.error, "[Request] No input item")
            return
        }

        // Extract message from request
        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request.userInfo?[SFExtensionMessageKey]
        } else {
            message = request.userInfo?["message"]
        }

        os_log(
            .debug,
            "[Request] Message: %{public}@",
            String(describing: message)
        )

        // Handle DNS lookup asynchronously
        Task {
            let responseMessage: [String: Any]

            if let messageDict = message as? [String: Any],
                messageDict["cmd"] as? String == "lookup",
                let domain = messageDict["domain"] as? String
            {
                let summary = await DNSResolver.lookupDomain(domain) { message in
                    os_log(.debug, "%{public}@", message)
                }
                if summary.addresses.isEmpty {
                    os_log(
                        .error,
                        "[Request] lookupDomain failed domain=%{public}@",
                        domain
                    )
                    responseMessage = ["error": "DNS lookup failed"]
                } else {
                    os_log(
                        .debug,
                        "[Request] lookupDomain success domain=%{public}@ count=%{public}ld",
                        domain,
                        summary.addresses.count
                    )
                    responseMessage = [
                        "addresses": summary.addresses.map { [
                            "address": $0.address,
                            "version": $0.version,
                        ] },
                        "tcpAddress": summary.tcpVerifiedAddress ?? NSNull(),
                    ]
                }
            } else {
                os_log(.debug, "[Request] Echoing message")
                responseMessage = ["echo": message ?? ""]
            }

            // Send response back
            let response = NSExtensionItem()
            if #available(iOS 15.0, macOS 11.0, *) {
                response.userInfo = [SFExtensionMessageKey: responseMessage]
            } else {
                response.userInfo = ["message": responseMessage]
            }

            os_log(.debug, "[Request] beginRequest complete")
            context.completeRequest(
                returningItems: [response],
                completionHandler: nil
            )
        }
    }
}
