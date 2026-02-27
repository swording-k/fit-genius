import SwiftUI
import SwiftData

/// 训练日选择器组件 - 支持横向滚动和拖动排序
struct TrainingDaySelector: View {
    let sortedDays: [WorkoutDay]
    let plan: WorkoutPlan
    @Binding var selectedDayIndex: Int
    let modelContext: ModelContext
    
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部：标题 + 编辑按钮
            HStack {
                Text("训练日程")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if sortedDays.count > 1 {
                    editButton
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 主体：横向滚动或列表
            if editMode == .active {
                editModeList
            } else {
                normalModeScroll
            }
        }
    }
    
    // 编辑按钮
    private var editButton: some View {
        Button(action: {
            withAnimation {
                editMode = editMode == .active ? .inactive : .active
            }
        }) {
            Text(editMode == .active ? "完成" : "编辑顺序")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
    
    // 正常模式 - 横向滚动
    private var normalModeScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                    DayTabButton(
                        day: day,
                        plan: plan,
                        isSelected: selectedDayIndex == index
                    ) {
                        withAnimation {
                            selectedDayIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // 编辑模式 - 纵向列表
    private var editModeList: some View {
        let height = min(CGFloat(sortedDays.count) * 60 + 20, 300)
        return List {
            ForEach(sortedDays) { day in
                simpleRow(for: day)
            }
            .onMove(perform: moveDays)
        }
        .listStyle(.plain)
        .frame(height: height)
        .environment(\.editMode, .constant(.active))
    }
    
    // 简单行视图
    private func simpleRow(for day: WorkoutDay) -> some View {
        let index = sortedDays.firstIndex(where: { $0.id == day.id })
        let isSelected = index == selectedDayIndex
        
        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(day.dayNumber) 天")
                    .font(.headline)
                Text(day.isRestDay ? "休息日" : day.focus.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let idx = index {
                withAnimation {
                    selectedDayIndex = idx
                }
            }
        }
    }
    
    // 拖动处理
    private func moveDays(from source: IndexSet, to destination: Int) {
        withAnimation {
            var days = sortedDays
            days.move(fromOffsets: source, toOffset: destination)
            
            for (index, day) in days.enumerated() {
                day.dayNumber = index + 1
            }
            
            try? modelContext.save()
            
            if let firstSourceIndex = source.first {
                if firstSourceIndex == selectedDayIndex {
                    selectedDayIndex = destination > firstSourceIndex ? destination - 1 : destination
                } else if firstSourceIndex < selectedDayIndex && destination > selectedDayIndex {
                    selectedDayIndex -= 1
                } else if firstSourceIndex > selectedDayIndex && destination <= selectedDayIndex {
                    selectedDayIndex += 1
                }
            }
        }
    }
}
