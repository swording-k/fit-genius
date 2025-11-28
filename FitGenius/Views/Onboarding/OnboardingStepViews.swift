import SwiftUI

// MARK: - 基本信息输入页面
struct BasicInfoView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text("基本信息")
                    .font(.largeTitle)
                    .bold()
                Text("让我们了解一下您的基本情况")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 表单
            VStack(spacing: 16) {
                // 姓名
                VStack(alignment: .leading, spacing: 8) {
                    Text("姓名")
                        .font(.headline)
                    TextField("请输入您的姓名", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 年龄
                VStack(alignment: .leading, spacing: 8) {
                    Text("年龄")
                        .font(.headline)
                    TextField("请输入年龄", text: $viewModel.age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 身高
                VStack(alignment: .leading, spacing: 8) {
                    Text("身高 (cm)")
                        .font(.headline)
                    TextField("请输入身高", text: $viewModel.height)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 体重
                VStack(alignment: .leading, spacing: 8) {
                    Text("体重 (kg)")
                        .font(.headline)
                    TextField("请输入体重", text: $viewModel.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 伤病情况（可选）
                VStack(alignment: .leading, spacing: 8) {
                    Text("伤病情况（可选）")
                        .font(.headline)
                    TextField("如有伤病请说明，无则留空", text: $viewModel.injuries)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
            
            // 下一步按钮
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("下一步")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProceedFromBasicInfo ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!viewModel.canProceedFromBasicInfo)
        }
        .padding()
    }
}

// MARK: - 目标和环境选择页面
struct GoalAndEnvironmentView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("健身目标")
                            .font(.largeTitle)
                            .bold()
                        Text("选择您的健身目标和训练环境")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 健身目标
                    VStack(alignment: .leading, spacing: 12) {
                        Text("您的目标")
                            .font(.headline)
                        
                        ForEach(FitnessGoal.allCases) { goal in
                            Button(action: {
                                viewModel.selectedGoal = goal
                            }) {
                                HStack {
                                    Text(goal.localizedName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.selectedGoal == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedGoal == goal ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedGoal == goal ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    
                    // 训练环境
                    VStack(alignment: .leading, spacing: 12) {
                        Text("训练环境")
                            .font(.headline)
                        
                        ForEach(WorkoutEnvironment.allCases) { environment in
                            Button(action: {
                                viewModel.selectedEnvironment = environment
                            }) {
                                HStack {
                                    Text(environment.localizedName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.selectedEnvironment == environment {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedEnvironment == environment ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedEnvironment == environment ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            
            // 导航按钮（固定在底部）
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("上一步")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("下一步")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    BasicInfoView(viewModel: OnboardingViewModel())
}

#Preview {
    GoalAndEnvironmentView(viewModel: OnboardingViewModel())
}
