import SwiftUI
import SwiftData

// MARK: - 饮食统计视图（临时禁用）
struct DietStatsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("饮食统计功能")
                    .font(.title2)
                    .bold()
                
                Text("此功能正在开发中")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("统计")
        }
    }
}