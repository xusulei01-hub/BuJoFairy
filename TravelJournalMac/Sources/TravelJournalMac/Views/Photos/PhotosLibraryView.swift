import SwiftUI
import SwiftData

struct PhotosLibraryView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var selectedTrip: Trip?
    @State private var showCreateTrip = false
    @State private var newTripName = ""
    @State private var newTripDate = Date()

    var body: some View {
        Group {
            if let trip = selectedTrip {
                TripDetailView(trip: trip, onBack: { selectedTrip = nil })
            } else {
                tripListView
            }
        }
        .navigationTitle("照片库")
        .toolbar {
            ToolbarItem {
                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            createTripSheet
        }
    }

    private var tripListView: some View {
        List {
            ForEach(trips) { trip in
                Button {
                    selectedTrip = trip
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name)
                                .font(.headline)
                            Text(trip.startDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(trip.photos?.count ?? 0) 张")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var createTripSheet: some View {
        VStack(spacing: 16) {
            Text("新建旅行")
                .font(.headline)

            TextField("旅行名称", text: $newTripName)
                .textFieldStyle(.roundedBorder)

            DatePicker("出发日期", selection: $newTripDate, displayedComponents: .date)

            HStack {
                Button("取消") {
                    showCreateTrip = false
                }

                Button("创建") {
                    createTrip()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTripName.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }

    @Environment(\.modelContext) private var modelContext

    private func createTrip() {
        let trip = Trip(name: newTripName, startDate: newTripDate)
        modelContext.insert(trip)
        try? modelContext.save()
        newTripName = ""
        showCreateTrip = false
    }
}
