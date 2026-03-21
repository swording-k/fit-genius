import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct DietHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DietViewModel
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: DietViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("date", selection: $viewModel.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .onChange(of: viewModel.selectedDate) { _, _ in
                    viewModel.loadDay()
                }

            if let day = viewModel.day {
                List {
                    if let s = day.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("daily_total_intake")
                                .font(.headline)
                            HStack(spacing: 12) {
                                Text(String(format: "%.0f kcal", s.totalCalories))
                                Text(String(format: "protein %.0f g", s.protein))
                                Text(String(format: "carbs %.0f g", s.carbs))
                                Text(String(format: "fat %.0f g", s.fat))
                            }
                            if !s.notes.isEmpty {
                                Text(s.notes).foregroundColor(.secondary)
                            }
                        }
                    }
                    ForEach(day.entries ?? []) { entry in
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
                                Label("edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                viewModel.deleteEntry(entry)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Text("no_record")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("diet_record")
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
                        Text(viewModel.isSubmitting ? "submitting".localized : "submit_diet_analysis".localized)
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
                    Picker("meal_type", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("description_optional", text: $viewModel.inputText, axis: .vertical)

                    Section {
                        HStack {
                            PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("select_image")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }

                        HStack {
                            Button {
                                showCamera = true
                            } label: {
                                HStack {
                                    Image(systemName: "camera")
                                    Text("take_photo")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }
                    } header: {
                        Text("images")
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
                .navigationTitle("add_meal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel") { viewModel.isPresentingAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("save") { viewModel.addMealEntry() }
                            .disabled(viewModel.selectedImagesData.isEmpty && viewModel.inputText.isEmpty)
                    }
                }
                .onAppear {
                    photoItems = []
                    viewModel.selectedImagesData = []
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
                .sheet(isPresented: $showCamera) {
                    CameraPicker(selectedImage: $capturedImage)
                }
                .onChange(of: capturedImage) { _, newImage in
                    if let image = newImage, let data = image.jpegData(compressionQuality: 0.8) {
                        viewModel.selectedImagesData.append(data)
                        capturedImage = nil
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingEditSheet) {
            NavigationStack {
                Form {
                    Section("content") {
                        TextField("description", text: $viewModel.editText, axis: .vertical)
                    }
                    Section("nutrition") {
                        TextField("calories_kcal", text: $viewModel.editCalories)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("protein_g", text: $viewModel.editProtein)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("carbs_g", text: $viewModel.editCarbs)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("fat_g", text: $viewModel.editFat)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                .navigationTitle("edit_meal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel") { viewModel.isPresentingEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("save") { viewModel.saveEdit() }
                    }
                }
            }
        }
        .alert("submit_result", isPresented: $viewModel.showSubmitAlert) {
            Button("ok") {}
        } message: {
            Text(viewModel.submitAlertMessage)
        }
    }
}
