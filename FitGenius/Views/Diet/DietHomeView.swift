import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct DietHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DietViewModel
    @State private var photoItems: [PhotosPickerItem] = []

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: DietViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("日期", selection: $viewModel.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .onChange(of: viewModel.selectedDate) { _, _ in
                    viewModel.loadDay()
                }

            if let day = viewModel.day {
                List {
                    if let s = day.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("当天总摄入")
                                .font(.headline)
                            HStack(spacing: 12) {
                                Text(String(format: "%.0f kcal", s.totalCalories))
                                Text(String(format: "蛋白 %.0f g", s.protein))
                                Text(String(format: "碳水 %.0f g", s.carbs))
                                Text(String(format: "脂肪 %.0f g", s.fat))
                            }
                            if !s.notes.isEmpty {
                                Text(s.notes).foregroundColor(.secondary)
                            }
                        }
                    }
                    ForEach(day.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.mealType.rawValue)
                                Spacer()
                                Text(String(format: "%.0f kcal", entry.calories))
                            }
                            if !entry.text.isEmpty {
                                Text(entry.text)
                                    .foregroundColor(.secondary)
                            }
                            if !entry.images.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(entry.images.enumerated()), id: \.offset) { _, data in
                                            if let image = UIImage(data: data) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipped()
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                viewModel.startEdit(entry: entry)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                viewModel.deleteEntry(entry)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Text("暂无记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("饮食记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    Task { await viewModel.submitDayForAnalysis() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting { ProgressView().tint(.white) }
                        Text(viewModel.isSubmitting ? "正在提交..." : "提交当天饮食分析")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(viewModel.isSubmitting ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
        .onAppear {
            viewModel.loadDay()
        }
        .sheet(isPresented: $viewModel.isPresentingAddSheet) {
            NavigationStack {
                Form {
                    Picker("餐次", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("描述（可选）", text: $viewModel.inputText, axis: .vertical)
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("选择图片")
                        }
                    }
                    if !viewModel.selectedImagesData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(viewModel.selectedImagesData.enumerated()), id: \.offset) { _, data in
                                    if let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("添加餐次")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { viewModel.isPresentingAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { viewModel.addMealEntry() }
                            .disabled(photoItems.isEmpty && viewModel.inputText.isEmpty)
                    }
                }
                .onChange(of: photoItems) { _, items in
                    Task {
                        var datas: [Data] = []
                        for item in items {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                datas.append(data)
                            }
                        }
                        viewModel.selectedImagesData = datas
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingEditSheet) {
            NavigationStack {
                Form {
                    Section("内容") {
                        TextField("描述", text: $viewModel.editText, axis: .vertical)
                    }
                    Section("营养") {
                        TextField("热量(kcal)", text: $viewModel.editCalories)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("蛋白质(g)", text: $viewModel.editProtein)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("碳水(g)", text: $viewModel.editCarbs)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("脂肪(g)", text: $viewModel.editFat)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                .navigationTitle("编辑餐次")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { viewModel.isPresentingEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { viewModel.saveEdit() }
                    }
                }
            }
        }
        .alert("提交结果", isPresented: $viewModel.showSubmitAlert) {
            Button("好的") {}
        } message: {
            Text(viewModel.submitAlertMessage)
        }
    }
}