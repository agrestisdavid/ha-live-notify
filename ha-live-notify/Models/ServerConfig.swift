import Foundation

struct ServerConfig: Equatable {
    var baseURL: String
    var accessToken: String

    var isValid: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && websocketURL != nil
    }

    var websocketURL: URL? {
        var urlString = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if urlString.hasPrefix("https://") {
            urlString = urlString.replacingOccurrences(of: "https://", with: "wss://")
        } else if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "ws://")
        } else {
            urlString = "wss://\(urlString)"
        }

        guard let url = URL(string: "\(urlString)/api/websocket"),
              isAllowedHost(url)
        else { return nil }

        return url
    }

    var restURL: URL? {
        var urlString = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }

        guard let url = URL(string: urlString),
              isAllowedHost(url)
        else { return nil }

        return url
    }

    /// Whether the connection uses encryption (wss/https)
    var isSecureConnection: Bool {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("https://") || trimmed.hasPrefix("wss://")
    }

    /// Validates that the URL points to a plausible HA instance.
    /// Plain HTTP is only allowed for local/private network addresses.
    /// Public addresses require HTTPS/WSS.
    private func isAllowedHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let scheme = url.scheme?.lowercased() ?? ""

        let isSecure = scheme == "https" || scheme == "wss"
        if isSecure { return true }

        // Plain HTTP/WS only allowed for private networks
        let isLocal = host == "localhost"
            || host == "127.0.0.1"
            || host == "::1"
            || host.hasSuffix(".local")
            || host.hasSuffix(".home")
            || host.hasSuffix(".internal")
            || host.hasSuffix(".lan")
            || isPrivateIP(host)

        return isLocal
    }

    private func isPrivateIP(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return false }

        // RFC 1918 private ranges
        if parts[0] == 10 { return true }                                      // 10.0.0.0/8
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }     // 172.16.0.0/12
        if parts[0] == 192 && parts[1] == 168 { return true }                  // 192.168.0.0/16
        if parts[0] == 169 && parts[1] == 254 { return true }                  // 169.254.0.0/16 (link-local)

        return false
    }
}
