import AuthenticationServices
import Foundation

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn = false
    @Published var userName: String?
    @Published var userID: String?

    override private init() {
        super.init()
        isLoggedIn = KeychainManager.shared.get(key: "auth_token") != nil
        userName = KeychainManager.shared.get(key: "user_name")
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

            let appleUserID = credential.user
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
                    let body = ["appleUserID": appleUserID, "name": name.isEmpty ? nil : name]
                    let result: AuthResponse = try await APIClient.shared.request(
                        "/auth/apple", method: "POST", body: body
                    )
                    APIClient.shared.setToken(result.token)
                    self.isLoggedIn = true
                    self.userName = result.user.name ?? "旅行者"
                    self.userID = result.user.id
                    KeychainManager.shared.save(key: "user_name", value: self.userName!)
                } catch {
                    // 离线模式：本地生成临时 token
                    let localToken = "local-\(appleUserID)"
                    APIClient.shared.setToken(localToken)
                    self.isLoggedIn = true
                    self.userName = name.isEmpty ? "旅行者" : name
                    KeychainManager.shared.save(key: "user_name", value: self.userName!)
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }

    func signOut() {
        KeychainManager.shared.delete(key: "auth_token")
        KeychainManager.shared.delete(key: "user_name")
        isLoggedIn = false
        userName = nil
        userID = nil
    }
}
