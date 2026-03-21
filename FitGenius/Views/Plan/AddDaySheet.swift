import SwiftUI

struct AddDaySheet: View {
    let plan: WorkoutPlan?
    let onCreate: (BodyPartFocus, Bool) -> Void
    @State private var selectedFocus: BodyPartFocus = .fullBody
    @State private var isRestDay: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("type") {
                    Toggle("rest_day", isOn: $isRestDay)
                }
                if !isRestDay {
                    Section("training_focus") {
                        Picker("body_part", selection: $selectedFocus) {
                            ForEach(BodyPartFocus.allCases, id: \.self) { focus in
                                Text(focus.localizedName).tag(focus)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }
            .navigationTitle("add_training_day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("add") {
                        onCreate(selectedFocus, isRestDay)
                    }
                }
            }
        }
    }
}