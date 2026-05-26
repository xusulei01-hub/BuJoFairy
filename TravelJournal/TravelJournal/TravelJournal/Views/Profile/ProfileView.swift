import SwiftUI
import AuthenticationServices
import SwiftData

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var apiKeyInput = ""
    @State private var showAPIKeySaved = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportMessage: String?

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
                        SecureField("AIza...", text: $apiKeyInput)
                            .font(.caption)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("保存") {
                            let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            KeychainManager.shared.save(key: "gemini_api_key", value: trimmed)
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
                    Text("在 aistudio.google.com 注册并获取 Gemini API Key。Key 仅存储在设备本地，不会上传服务器。")
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
                        exportAllJournals()
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
                apiKeyInput = KeychainManager.shared.get(key: "gemini_api_key") ?? ""
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("导出", isPresented: .init(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )) {
                Button("确定") {}
            } message: {
                Text(exportMessage ?? "")
            }
        }
    }

    private func exportAllJournals() {
        do {
            let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let journals = try modelContext.fetch(descriptor)

            guard !journals.isEmpty else {
                exportMessage = "没有可导出的手帐"
                return
            }

            var exportItems: [[String: String]] = []
            let formatter = ISO8601DateFormatter()
            for journal in journals {
                var item: [String: String] = [:]
                item["id"] = journal.id.uuidString
                item["title"] = journal.title
                item["templateID"] = journal.templateID
                item["tripName"] = journal.trip?.name ?? ""
                item["createdAt"] = formatter.string(from: journal.createdAt)
                item["content"] = String(data: journal.contentJSON, encoding: .utf8) ?? ""
                exportItems.append(item)
            }

            let jsonData = try JSONSerialization.data(withJSONObject: exportItems, options: .prettyPrinted)

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "travel-journals-\(ISO8601DateFormatter().string(from: Date())).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            try jsonData.write(to: fileURL)

            exportURL = fileURL
            showShareSheet = true
        } catch {
            exportMessage = "导出失败: \(error.localizedDescription)"
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
