import SwiftUI
import SwiftData

struct PhotosView: View {
    @StateObject private var viewModel = PhotosViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trips.isEmpty {
                    ContentUnavailableView(
                        "还没有旅行记录",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("创建你的第一次旅行，开始记录精彩瞬间")
                    )
                } else {
                    List {
                        ForEach(viewModel.trips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                TripRowView(trip: trip)
                            }
                        }
                        .onDelete(perform: deleteTrips)
                    }
                }
            }
            .navigationTitle("照片库")
            .toolbar {
                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView { name, startDate in
                    viewModel.createTrip(name: name, startDate: startDate, modelContext: modelContext)
                }
            }
            .onAppear {
                viewModel.loadTrips(modelContext: modelContext)
            }
        }
    }

    private func deleteTrips(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(viewModel.trips[index])
        }
        try? modelContext.save()
        viewModel.loadTrips(modelContext: modelContext)
    }
}

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.headline)
                Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(trip.photos?.count ?? 0) 张照片")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
