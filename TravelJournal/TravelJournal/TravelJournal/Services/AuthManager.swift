import AuthenticationServices
import Combine
import Foundation

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn = false
    @Published var userName: String?
    @Published var userID: String?
    @Published var authError: String?

    override private init() {
        super.init()
        isLoggedIn = KeychainManager.shared.get(key: "auth_token") != nil
        userName = KeychainManager.shared.get(key: "user_name")
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "无法获取 Apple 登录凭据"
                return
            }

            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                authError = "无法获取 identityToken"
                return
            }

            let fullName = credential.fullName
            let name = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                do {
                    struct AuthResponse: Codable {
                        let token: String
                        let user: UserInfo
                        struct UserInfo: Codable {
                            let id: String
                            let name: String?
                        }
                    }
                    struct AppleSignInRequest: Encodable {
                        let appleUserID: String
                        let name: String?
                        let identityToken: String
                    }
                    let body = AppleSignInRequest(
                        appleUserID: credential.user,
                        name: name.isEmpty ? nil : name,
                        identityToken: identityToken
                    )
                    let result: AuthResponse = try await APIClient.shared.request(
                        "/auth/apple", method: "POST", body: body, requiresAuth: false
                    )
                    APIClient.shared.setToken(result.token)
                    self.isLoggedIn = true
                    self.userName = result.user.name ?? "旅行者"
                    self.userID = result.user.id
                    self.authError = nil
                    KeychainManager.shared.save(key: "user_name", value: self.userName!)
                } catch {
                    self.authError = error.localizedDescription
                    self.isLoggedIn = false
                }
            }
        case .failure(let error):
            authError = "Apple 登录失败: \(error.localizedDescription)"
        }
    }

    func signOut() {
        KeychainManager.shared.delete(key: "auth_token")
        KeychainManager.shared.delete(key: "user_name")
        isLoggedIn = false
        userName = nil
        userID = nil
        authError = nil
    }
}
