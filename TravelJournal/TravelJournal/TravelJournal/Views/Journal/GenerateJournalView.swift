import SwiftUI
import SwiftData

struct GenerateJournalView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()
    @State private var enableWebSearch = false

    var body: some View {
        NavigationStack {
            Form {
                Section("选择模板") {
                    Picker("模板风格", selection: $viewModel.selectedTemplateID) {
                        ForEach(viewModel.getBuiltInTemplates()) { template in
                            HStack {
                                Text(template.name)
                                Spacer()
                                Text(template.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(template.id)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("生成选项") {
                    Toggle(isOn: $enableWebSearch) {
                        VStack(alignment: .leading) {
                            Text("联网搜索补充知识")
                            Text("开启后 Gemini 将搜索网络上的地点背景知识，丰富手帐内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = viewModel.generationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task {
                            await viewModel.generateJournal(
                                for: trip,
                                enableWebSearch: enableWebSearch,
                                modelContext: modelContext
                            )
                        }
                    } label: {
                        HStack {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .tint(.white)
                                Text("AI 正在为你创作...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("一键生成手帐")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isGenerating)
                    .listRowBackground(Color.blue)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("生成手帐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: viewModel.generatedContent) { _, content in
                if content != nil {
                    dismiss()
                }
            }
        }
    }
}
