import SwiftUI
import SwiftData

struct JournalListView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journals: [JournalEntry]
    @State private var selectedJournal: JournalEntry?

    var body: some View {
        Group {
            if let journal = selectedJournal {
                JournalReaderView(journal: journal, onBack: { selectedJournal = nil })
            } else {
                listView
            }
        }
        .navigationTitle("手帐库")
    }

    private var listView: some View {
        List {
            ForEach(journals) { journal in
                Button {
                    selectedJournal = journal
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(journal.title)
                                .font(.headline)
                            Text(journal.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let tripName = journal.trip?.name {
                                Text(tripName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}
