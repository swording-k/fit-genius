import SwiftUI

struct AddDaySheet: View {
    let plan: WorkoutPlan?
    let onCreate: (BodyPartFocus, Bool) -> Void
    @State private var selectedFocus: BodyPartFocus = .fullBody
    @State private var isRestDay: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Toggle("休息日", isOn: $isRestDay)
                }
                if !isRestDay {
                    Section("训练部位") {
                        Picker("部位", selection: $selectedFocus) {
                            ForEach(BodyPartFocus.allCases, id: \.self) { focus in
                                Text(focus.localizedName).tag(focus)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }
            .navigationTitle("新增训练日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onCreate(selectedFocus, isRestDay)
                    }
                }
            }
        }
    }
}