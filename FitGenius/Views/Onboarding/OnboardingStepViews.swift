import SwiftUI

// MARK: - 基本信息输入页面
struct BasicInfoView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Field?
    enum Field { case name, age, height, weight }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text("basic_info_title")
                    .font(.largeTitle)
                    .bold()
                Text("basic_info_subtitle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 表单
            VStack(spacing: 16) {
                // 姓名
                VStack(alignment: .leading, spacing: 8) {
                    Text("name")
                        .font(.headline)
                    TextField("enter_name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                }

                // 年龄
                VStack(alignment: .leading, spacing: 8) {
                    Text("age")
                        .font(.headline)
                    TextField("enter_age", text: $viewModel.age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .age)
                }

                // 身高
                VStack(alignment: .leading, spacing: 8) {
                    Text("height_cm")
                        .font(.headline)
                    TextField("enter_height", text: $viewModel.height)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .height)
                }

                // 体重
                VStack(alignment: .leading, spacing: 8) {
                    Text("weight_kg")
                        .font(.headline)
                    TextField("enter_weight", text: $viewModel.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .weight)
                }
            }

            Spacer()

            // 下一步按钮
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("next")
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
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done") { focusedField = nil }
            }
        }
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
                        Text("fitness_goal_title")
                            .font(.largeTitle)
                            .bold()
                        Text("fitness_goal_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 健身目标
                    VStack(alignment: .leading, spacing: 12) {
                        Text("your_goal")
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
                        Text("training_environment")
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
            .scrollDismissesKeyboard(.interactively)

            // 导航按钮（固定在底部）
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("previous")
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
                        Text("next")
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
