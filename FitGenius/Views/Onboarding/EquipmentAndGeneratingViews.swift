import SwiftUI
import SwiftData

// MARK: - 器械选择页面
struct EquipmentSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text("available_equipment")
                    .font(.largeTitle)
                    .bold()
                Text("select_equipment_subtitle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 快捷按钮（仅在健身房环境显示）
            if viewModel.selectedEnvironment == .gym {
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.selectAllEquipment()
                    }) {
                        Label("select_all", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        viewModel.clearAllEquipment()
                    }) {
                        Label("clear_all", systemImage: "xmark.circle")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }

            // 器械网格
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.commonEquipment, id: \.self) { equipment in
                        Button(action: {
                            viewModel.toggleEquipment(equipment)
                        }) {
                            HStack {
                                Text(equipment)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedEquipment.contains(equipment) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedEquipment.contains(equipment) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.selectedEquipment.contains(equipment) ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // 已选择数量提示
            if !viewModel.selectedEquipment.isEmpty {
                Text("selected_equipment_count".localized(with: viewModel.selectedEquipment.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 导航按钮
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
                        .background(viewModel.canProceedFromEquipment ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.canProceedFromEquipment)
            }
        }
        .padding()
    }
}

// MARK: - 生成中页面
struct GeneratingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    @Binding var hasOnboarded: Bool
    @State private var spin = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 动画图标
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            spin = true
                        }
                    }

                Image(systemName: "figure.run")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }

            // 状态文本
            VStack(spacing: 12) {
                Text(viewModel.isGenerating ? "generating_plan".localized : "completed".localized)
                    .font(.title2)
                    .bold()

                Text(viewModel.generationProgress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 错误信息
            if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("generation_failed")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)

                    Button(action: {
                        startGeneration()
                    }) {
                        Text("retry")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }

            Spacer()
        }
        .padding()

        // 生成流程由按钮触发，保留重试按钮使用
    }

    private func startGeneration() {
        viewModel.generatePlan(context: modelContext) { success in
            if success {
                // 延迟 2 秒确保 SwiftData 完全刷新
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    hasOnboarded = true
                }
            }
        }
    }
}

// MARK: - 备注输入页面（与器械选择拆分）
struct NotesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("notes_title")
                .font(.largeTitle)
                .bold()
            Text("notes_subtitle")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $viewModel.notes)
                .focused($notesFocused)
                .frame(minHeight: 160)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            Spacer()
            HStack(spacing: 12) {
                Button(action: { viewModel.previousStep() }) {
                    Text("previous")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                Button(action: {
                    notesFocused = false
                    viewModel.nextStep()
                    viewModel.generatePlan(context: modelContext) { success in
                        if success { hasOnboarded = true }
                    }
                }) {
                    Text("generate_plan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done") { notesFocused = false }
            }
        }
    }
}

#Preview {
    EquipmentSelectionView(viewModel: OnboardingViewModel())
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, configurations: config)
    
    GeneratingView(viewModel: OnboardingViewModel(), hasOnboarded: .constant(false))
        .modelContainer(container)
}
