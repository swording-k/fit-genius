import SwiftUI
import SwiftData

// MARK: - Onboarding 主容器视图
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // 进度指示器
                if viewModel.currentStep != .generating {
                    ProgressIndicator(currentStep: viewModel.currentStep)
                        .padding(.top)
                }
                
                // 步骤内容
                TabView(selection: $viewModel.currentStep) {
                    BasicInfoView(viewModel: viewModel)
                        .tag(OnboardingStep.basicInfo)
                    
                    GoalAndEnvironmentView(viewModel: viewModel)
                        .tag(OnboardingStep.goalAndEnvironment)
                    
                    EquipmentSelectionView(viewModel: viewModel)
                        .tag(OnboardingStep.equipment)
                    
                    NotesView(viewModel: viewModel)
                        .tag(OnboardingStep.notes)
                    
                    GeneratingView(viewModel: viewModel, hasOnboarded: $hasOnboarded)
                        .tag(OnboardingStep.generating)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)
            }
        }
    }
}

// MARK: - 进度指示器
struct ProgressIndicator: View {
    let currentStep: OnboardingStep
    
    private let steps = ["基本信息", "目标设定", "器械选择", "备注"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 4) {
                    // 圆圈
                    Circle()
                        .fill(index <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                        )
                    
                    // 标签
                    Text(steps[index])
                        .font(.caption2)
                        .foregroundColor(index <= currentStep.rawValue ? .primary : .secondary)
                }
                
                // 连接线
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, configurations: config)
    
    OnboardingView()
        .modelContainer(container)
}
