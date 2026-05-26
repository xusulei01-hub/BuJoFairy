import SwiftUI
import SwiftData

struct GenerateJournalView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("生成手帐")
                .font(.headline)

            Picker("模板风格", selection: $viewModel.selectedTemplateID) {
                ForEach(viewModel.getBuiltInTemplates()) { template in
                    Text(template.name).tag(template.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 240)

            if let error = viewModel.generationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }

                Button {
                    Task {
                        await viewModel.generateJournal(
                            for: trip,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("生成中...")
                        }
                    } else {
                        Label("一键生成", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGenerating)
            }
        }
        .padding()
        .frame(width: 360, height: 200)
        .onChange(of: viewModel.generatedContent) { _, content in
            if content != nil {
                dismiss()
            }
        }
    }
}
