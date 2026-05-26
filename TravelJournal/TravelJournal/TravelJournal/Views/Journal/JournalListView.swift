import SwiftUI
import SwiftData

struct JournalListView: View {
    @StateObject private var viewModel = JournalViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.journals.isEmpty {
                    ContentUnavailableView(
                        "还没有手帐",
                        systemImage: "book.pages",
                        description: Text("在照片库中选择旅行，一键生成精美手帐")
                    )
                } else {
                    List {
                        ForEach(viewModel.journals) { journal in
                            NavigationLink(destination: JournalReaderView(journal: journal)) {
                                JournalRowView(journal: journal)
                            }
                        }
                        .onDelete(perform: deleteJournals)
                    }
                }
            }
            .navigationTitle("手帐库")
            .onAppear {
                viewModel.loadJournals(modelContext: modelContext)
            }
            .alert("错误", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("确定") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func deleteJournals(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(viewModel.journals[index])
        }
        viewModel.save(modelContext: modelContext)
    }
}

private struct JournalRowView: View {
    let journal: JournalEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.3), .pink.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 80)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(journal.title)
                    .font(.headline)
                    .lineLimit(1)
                if let tripName = journal.trip?.name {
                    Text(tripName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(journal.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
