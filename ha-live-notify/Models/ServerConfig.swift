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

    var isSecureConnection: Bool {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("https://") || trimmed.hasPrefix("wss://")
    }

    private func isAllowedHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let scheme = url.scheme?.lowercased() ?? ""

        let isSecure = scheme == "https" || scheme == "wss"
        if isSecure { return true }

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

        if parts[0] == 10 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 169 && parts[1] == 254 { return true }

        return false
    }
}
