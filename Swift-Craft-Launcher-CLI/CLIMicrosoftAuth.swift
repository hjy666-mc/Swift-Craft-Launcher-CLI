import Foundation

enum CLIAuthError: Error, CustomStringConvertible, LocalizedError {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }

    var errorDescription: String? {
        return description
    }
}

enum CLIAppConstants {
    static let minecraftScope = "XboxLive.signin offline_access"

    static let minecraftClientId: String = {
        if let env = ProcessInfo.processInfo.environment["SCL_CLIENT_ID"], !env.isEmpty {
            return env
        }
        let encrypted = "$(CLIENTID)"
        let value = CLIObfuscator.decryptClientID(encrypted)
        return value
    }()
}

enum CLIURLConfig {
    enum Authentication {
        static let deviceCode = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
        static let token = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        static let xboxLiveAuth = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
        static let xstsAuth = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
        static let minecraftLogin = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
        static let minecraftProfile = URL(string: "https://api.minecraftservices.com/minecraft/profile")!
        static let minecraftEntitlements = URL(string: "https://api.minecraftservices.com/entitlements/mcstore")!
    }
}

enum CLIObfuscator {
    private static let xorKey: UInt8 = 0x7A
    private static let indexOrder = [3, 0, 5, 1, 4, 2]

    private static func decrypt(_ input: String) -> String {
        guard let data = Data(base64Encoded: input) else { return "" }
        let bytes = data.map { ($0 ^ xorKey) >> 3 | ($0 ^ xorKey) << 5 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    static func decryptClientID(_ encryptedString: String) -> String {
        if encryptedString.isEmpty || encryptedString.contains("$(") {
            return ""
        }
        let partLength = 8
        guard encryptedString.count >= partLength * 6 else {
            return ""
        }
        var parts: [String] = []
        for i in 0..<6 {
            let startIndex = encryptedString.index(encryptedString.startIndex, offsetBy: i * partLength)
            let endIndex = encryptedString.index(startIndex, offsetBy: partLength)
            let part = String(encryptedString[startIndex..<endIndex])
            parts.append(part)
        }
        var restoredParts = Array(repeating: "", count: parts.count)
        for (j, part) in parts.enumerated() {
            if let i = indexOrder.firstIndex(of: j) {
                restoredParts[i] = decrypt(part)
            }
        }
        return restoredParts.joined()
    }
}

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let verificationUriComplete: String?
    let expiresIn: Int
    let interval: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
        case message
    }
}

struct OAuthTokenResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case error
        case errorDescription = "error_description"
    }
}

struct XboxLiveTokenResponse: Codable {
    let token: String
    let displayClaims: DisplayClaims

    enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

struct DisplayClaims: Codable {
    let xui: [XUI]
}

struct XUI: Codable {
    let uhs: String
}

struct MinecraftTokenResponse: Codable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct MinecraftProfileResponse: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?
}

struct Skin: Codable, Equatable {
    let state: String
    let url: String
    let variant: String?
}

struct Cape: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}

struct MinecraftEntitlementsResponse: Codable {
    let items: [EntitlementItem]
}

struct EntitlementItem: Codable {
    let name: String
}

struct AuthCredential: Codable, Equatable {
    let userId: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date?
    var xuid: String
}

enum CLIHTTP {
    static func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    static func post(url: URL, body: Data?, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    static func postWithResponse(url: URL, body: Data?, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CLIAuthError.message("无效的 HTTP 响应")
        }
        return (data, http)
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CLIAuthError.message("无效的 HTTP 响应")
        }
        guard (200...299).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                throw CLIAuthError.message("请求失败: HTTP \(http.statusCode) - \(text)")
            }
            throw CLIAuthError.message("请求失败: HTTP \(http.statusCode)")
        }
    }
}

enum JWTDecoder {
    private static func addPadding(to base64String: String) -> String {
        var padded = base64String
        let remainder = padded.count % 4
        if remainder > 0 {
            padded = "\(padded)\(String(repeating: "=", count: 4 - remainder))"
        }
        return padded
    }

    static func extractExpirationTime(from jwt: String) -> Date? {
        let components = jwt.components(separatedBy: ".")
        guard components.count == 3 else { return nil }
        let payload = addPadding(to: components[1])
        guard let payloadData = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    static func isTokenExpiringSoon(_ jwt: String, bufferTime: TimeInterval = 300) -> Bool {
        guard let expiration = extractExpirationTime(from: jwt) else { return true }
        return Date() >= expiration.addingTimeInterval(-bufferTime)
    }

    static func getMinecraftTokenExpiration(from token: String) -> Date {
        return extractExpirationTime(from: token) ?? Date().addingTimeInterval(24 * 60 * 60)
    }
}

enum CLIMicrosoftAuth {
    static func loginDeviceCode(progress: ((String) -> Void)? = nil) async throws -> (MinecraftProfileResponse, AuthCredential) {
        let clientId = CLIAppConstants.minecraftClientId
        guard !clientId.isEmpty, !clientId.contains("$(") else {
            throw CLIAuthError.message("缺少 Microsoft Client ID。请用 `export SCL_CLIENT_ID=...` 或 `SCL_CLIENT_ID=... scl account create -microsoft`")
        }

        let device = try await requestDeviceCode(clientId: clientId)
        progress?(device.message ?? "请在浏览器中完成 Microsoft 登录")

        if let url = URL(string: device.verificationUriComplete ?? device.verificationUri) {
            openURL(url)
        }

        let token = try await pollDeviceCodeToken(
            clientId: clientId,
            deviceCode: device.deviceCode,
            interval: device.interval ?? 5,
            expiresIn: device.expiresIn
        )

        let xboxToken = try await getXboxLiveToken(accessToken: token.accessToken ?? "")
        let xuid = xboxToken.displayClaims.xui.first?.uhs ?? ""
        let minecraftToken = try await getMinecraftToken(xboxToken: xboxToken.token, uhs: xuid)
        try await checkMinecraftOwnership(accessToken: minecraftToken)
        let profile = try await getMinecraftProfile(accessToken: minecraftToken)

        let credential = AuthCredential(
            userId: profile.id,
            accessToken: minecraftToken,
            refreshToken: token.refreshToken ?? "",
            expiresAt: JWTDecoder.getMinecraftTokenExpiration(from: minecraftToken),
            xuid: xuid
        )
        return (profile, credential)
    }

    static func refreshIfNeeded(_ credential: AuthCredential) async throws -> AuthCredential {
        if !JWTDecoder.isTokenExpiringSoon(credential.accessToken) {
            return credential
        }
        guard !credential.refreshToken.isEmpty else {
            throw CLIAuthError.message("登录已过期，请重新登录该账户")
        }
        let refreshed = try await refreshToken(refreshToken: credential.refreshToken)
        guard let access = refreshed.accessToken else {
            throw CLIAuthError.message("刷新令牌失败")
        }
        let xboxToken = try await getXboxLiveToken(accessToken: access)
        let xuid = xboxToken.displayClaims.xui.first?.uhs ?? ""
        let minecraftToken = try await getMinecraftToken(xboxToken: xboxToken.token, uhs: xuid)
        var updated = credential
        updated.accessToken = minecraftToken
        updated.refreshToken = refreshed.refreshToken ?? credential.refreshToken
        updated.expiresAt = JWTDecoder.getMinecraftTokenExpiration(from: minecraftToken)
        updated.xuid = xuid
        return updated
    }

    private static func requestDeviceCode(clientId: String) async throws -> DeviceCodeResponse {
        let body = "client_id=\(clientId)&scope=\(CLIAppConstants.minecraftScope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        let data = try await CLIHTTP.post(
            url: CLIURLConfig.Authentication.deviceCode,
            body: body.data(using: .utf8),
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private static func pollDeviceCodeToken(clientId: String, deviceCode: String, interval: Int, expiresIn: Int) async throws -> OAuthTokenResponse {
        let start = Date()
        var waitInterval = interval
        while Date().timeIntervalSince(start) < TimeInterval(expiresIn) {
            let bodyParams: [String: String] = [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": clientId,
                "device_code": deviceCode,
            ]
            let body = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
            let data = try await CLIHTTP.post(
                url: CLIURLConfig.Authentication.token,
                body: body.data(using: .utf8),
                headers: ["Content-Type": "application/x-www-form-urlencoded"]
            )
            if let token = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data),
               let access = token.accessToken, !access.isEmpty {
                return token
            }
            let error = (try? JSONDecoder().decode(OAuthTokenResponse.self, from: data))?.error ?? ""
            if error == "authorization_pending" {
                try await Task.sleep(nanoseconds: UInt64(waitInterval) * 1_000_000_000)
                continue
            }
            if error == "slow_down" {
                waitInterval += 5
                try await Task.sleep(nanoseconds: UInt64(waitInterval) * 1_000_000_000)
                continue
            }
            if !error.isEmpty {
                throw CLIAuthError.message("Microsoft 登录失败: \(error)")
            }
            try await Task.sleep(nanoseconds: UInt64(waitInterval) * 1_000_000_000)
        }
        throw CLIAuthError.message("登录超时，请重试")
    }

    private static func refreshToken(refreshToken: String) async throws -> OAuthTokenResponse {
        let bodyParams: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": CLIAppConstants.minecraftClientId,
            "refresh_token": refreshToken,
        ]
        let body = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        let data = try await CLIHTTP.post(
            url: CLIURLConfig.Authentication.token,
            body: body.data(using: .utf8),
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private static func getXboxLiveToken(accessToken: String) async throws -> XboxLiveTokenResponse {
        let body: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(accessToken)",
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await CLIHTTP.post(
            url: CLIURLConfig.Authentication.xboxLiveAuth,
            body: bodyData,
            headers: ["Content-Type": "application/json"]
        )
        return try JSONDecoder().decode(XboxLiveTokenResponse.self, from: data)
    }

    private static func getMinecraftToken(xboxToken: String, uhs: String) async throws -> String {
        let xstsBody: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xboxToken],
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        ]
        let xstsData = try JSONSerialization.data(withJSONObject: xstsBody)
        let xstsResponse = try await CLIHTTP.post(
            url: CLIURLConfig.Authentication.xstsAuth,
            body: xstsData,
            headers: ["Content-Type": "application/json"]
        )
        let xstsToken = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: xstsResponse)

        let minecraftBody: [String: Any] = [
            "identityToken": "XBL3.0 x=\(uhs);\(xstsToken.token)"
        ]
        let minecraftBodyData = try JSONSerialization.data(withJSONObject: minecraftBody)
        let (data, http) = try await CLIHTTP.postWithResponse(
            url: CLIURLConfig.Authentication.minecraftLogin,
            body: minecraftBodyData,
            headers: ["Content-Type": "application/json"]
        )
        guard http.statusCode == 200 else {
            throw CLIAuthError.message("获取 Minecraft 访问令牌失败: HTTP \(http.statusCode)")
        }
        let token = try JSONDecoder().decode(MinecraftTokenResponse.self, from: data)
        return token.accessToken
    }

    private static func checkMinecraftOwnership(accessToken: String) async throws {
        let headers = ["Authorization": "Bearer \(accessToken)"]
        let data = try await CLIHTTP.get(url: CLIURLConfig.Authentication.minecraftEntitlements, headers: headers)
        let entitlements = try JSONDecoder().decode(MinecraftEntitlementsResponse.self, from: data)
        let names = entitlements.items.map(\.name)
        let hasProduct = names.contains("product_minecraft")
        let hasGame = names.contains("game_minecraft")
        if !hasProduct || !hasGame {
            throw CLIAuthError.message("该账户未购买 Minecraft")
        }
    }

    private static func getMinecraftProfile(accessToken: String) async throws -> MinecraftProfileResponse {
        let headers = ["Authorization": "Bearer \(accessToken)"]
        let data = try await CLIHTTP.get(url: CLIURLConfig.Authentication.minecraftProfile, headers: headers)
        return try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)
    }

    private static func openURL(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
    }
}
