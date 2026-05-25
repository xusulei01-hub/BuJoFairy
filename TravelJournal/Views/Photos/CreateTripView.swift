import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tripName = ""
    @State private var startDate = Date()
    let onCreate: (String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("旅行信息") {
                    TextField("旅行名称", text: $tripName)
                    DatePicker("出发日期", selection: $startDate, displayedComponents: .date)
                }

                Section {
                    Text("创建后即可导入照片，自动识别地点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建旅行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        guard !tripName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onCreate(tripName.trimmingCharacters(in: .whitespaces), startDate)
                        dismiss()
                    }
                    .disabled(tripName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
