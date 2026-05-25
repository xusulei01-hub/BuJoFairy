import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var apiKeyInput = ""
    @State private var showAPIKeySaved = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 登录
                Section {
                    if authManager.isLoggedIn {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.userName ?? "旅行者")
                                    .font(.headline)
                                Text("已通过 Apple 登录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Button("退出登录", role: .destructive) {
                            authManager.signOut()
                        }
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            authManager.handleAppleSignIn(result)
                        }
                        .frame(height: 44)
                    }
                } header: {
                    Text("账号")
                }

                // MARK: - AI 设置
                Section {
                    HStack {
                        SecureField("sk-...", text: $apiKeyInput)
                            .font(.caption)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("保存") {
                            let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            KeychainManager.shared.save(key: "deepseek_api_key", value: trimmed)
                            apiKeyInput = ""
                            showAPIKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showAPIKeySaved = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if showAPIKeySaved {
                        Label("API Key 已保存", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                } header: {
                    Text("AI 设置")
                } footer: {
                    Text("在 platform.deepseek.com 注册并获取你的 API Key。Key 仅存储在设备本地，不会上传服务器。")
                }

                // MARK: - 关联账号（预留）
                Section {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.red)
                        Text("小红书")
                        Spacer()
                        Text("即将上线")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "ellipsis.message.fill")
                            .foregroundStyle(.orange)
                        Text("微博")
                        Spacer()
                        Text("即将上线")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关联账号")
                } footer: {
                    Text("后续版本将支持关联社交账号，一键分享手帐")
                }

                // MARK: - 数据
                Section {
                    Button("导出所有手帐") {
                        // TODO: 实现导出
                    }
                } header: {
                    Text("数据管理")
                }

                // MARK: - 关于
                Section {
                    LabeledContent("版本", value: "0.1.0")
                    LabeledContent("构建", value: "1")
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("我的")
            .onAppear {
                apiKeyInput = KeychainManager.shared.get(key: "deepseek_api_key") ?? ""
            }
        }
    }
}
