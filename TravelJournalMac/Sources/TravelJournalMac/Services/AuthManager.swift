import Foundation
import AuthenticationServices

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn = false
    @Published var userName: String?
    @Published var userEmail: String?

    private init() {
        checkToken()
    }

    private func checkToken() {
        if let token = KeychainManager.shared.get(key: "auth_token"), !token.isEmpty {
            isLoggedIn = true
            userName = KeychainManager.shared.get(key: "user_name")
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                return
            }

            let name = credential.fullName
            let displayName = [name?.givenName, name?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                await authenticateWithServer(identityToken: tokenString, name: displayName)
            }

        case .failure:
            break
        }
    }

    private func authenticateWithServer(identityToken: String, name: String) async {
        struct AuthBody: Encodable {
            let identityToken: String
            let name: String?
        }

        do {
            let body = AuthBody(identityToken: identityToken, name: name.isEmpty ? nil : name)
            let response: AuthResponse = try await APIClient.shared.request(
                "/auth/apple",
                method: "POST",
                body: body,
                requiresAuth: false
            )

            APIClient.shared.setToken(response.token)
            KeychainManager.shared.save(key: "user_name", value: response.user.name)

            await MainActor.run {
                self.isLoggedIn = true
                self.userName = response.user.name
            }
        } catch {
            // Silently fail - user can retry
        }
    }

    func signOut() {
        APIClient.shared.setToken(nil)
        KeychainManager.shared.delete(key: "user_name")
        isLoggedIn = false
        userName = nil
    }
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserInfo
}

struct UserInfo: Decodable {
    let id: String
    let name: String
}
