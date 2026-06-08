import AuthenticationServices
import ComposableArchitecture

@DependencyClient
struct AuthClient {
    var signInWithApple: @Sendable () async throws -> String = { "" } // returns identity token
    var exchangeToken: @Sendable (String) async throws -> TokenPair = { _ in .init(accessToken: "", refreshToken: "") }
    var refreshAccessToken: @Sendable (String) async throws -> String = { _ in "" }
}

struct TokenPair: Equatable {
    let accessToken: String
    let refreshToken: String
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        signInWithApple: {
            try await withCheckedThrowingContinuation { continuation in
                let delegate = SignInDelegate(continuation: continuation)
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.email]
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = delegate
                // Retain delegate for the duration
                objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                controller.performRequests()
            }
        },
        exchangeToken: { identityToken in
            let url = URL(string: "http://localhost:8080/auth/apple")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["identity_token": identityToken])
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            return TokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken)
        },
        refreshAccessToken: { refreshToken in
            let url = URL(string: "http://localhost:8080/auth/refresh")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            return response.accessToken
        }
    )
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private final class SignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<String, Error>

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            continuation.resume(throwing: AuthError.missingToken)
            return
        }
        continuation.resume(returning: token)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

enum AuthError: Error { case missingToken }

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
