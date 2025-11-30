import SwiftUI
import SwiftData
import PhotosUI

struct DietLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var days: [MealDay]
    @State private var currentDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedMealName: String = "早餐"
    @State private var textEntry: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    private var day: MealDay {
        if let d = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }) { return d }
        let d = MealDay(date: currentDate)
        modelContext.insert(d)
        return d
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button("← 前一天") { shiftDay(-1) }
                    Spacer()
                    Text(dateString(currentDate)).font(.headline)
                    Spacer()
                    Button("后一天 →") { shiftDay(1) }
                }
                .padding(.horizontal)

                List {
                    Section(header: Text("今日记录")) {
                        ForEach(day.meals) { meal in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(meal.name).font(.headline)
                                ForEach(meal.entries) { e in
                                    if e.type == .text { Text("• \(e.text)").font(.subheadline) }
                                    else { Text("• 图片：\(URL(string: e.photoLocalURL)?.lastPathComponent ?? "")").font(.subheadline) }
                                }
                            }
                        }
                    }

                    Section(header: Text("添加一餐")) {
                        Picker("餐次", selection: $selectedMealName) {
                            Text("早餐").tag("早餐"); Text("午餐").tag("午餐"); Text("晚餐").tag("晚餐"); Text("加餐").tag("加餐")
                        }
                        TextField("例如：两碗米饭、一份鸡胸肉、半盘西兰花", text: $textEntry)
                        PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("选择图片", systemImage: "photo") }
                        if let data = selectedImageData, let img = UIImage(data: data) { Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 160) }
                        HStack {
                            Button("保存文字") { addTextEntry() }.disabled(textEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("保存图片") { addPhotoEntry() }.disabled(selectedImageData == nil)
                        }
                    }

                    Section(header: Text("分析")) {
                        if let a = day.analysis {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("热量：\(format(a.calories)) kcal")
                                Text("蛋白质：\(format(a.protein)) g  碳水：\(format(a.carbs)) g  脂肪：\(format(a.fat)) g")
                            }
                        } else {
                            Text("尚未分析今日饮食")
                        }
                        Button(isAnalyzing ? "分析中…" : "提交分析") { Task { await analyzeToday() } }.disabled(isAnalyzing || (day.meals.flatMap{ $0.entries }.isEmpty))
                        if let err = errorMessage { Text(err).foregroundColor(.red) }
                    }
                }
            }
            .navigationTitle("饮食")
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { selectedImageData = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    private func shiftDay(_ delta: Int) { currentDate = Calendar.current.date(byAdding: .day, value: delta, to: currentDate) ?? currentDate }
    private func dateString(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d) }
    private func format(_ v: Double) -> String { String(format: "%.0f", v) }

    private func findOrCreateMeal(name: String) -> Meal {
        if let m = day.meals.first(where: { $0.name == name }) { return m }
        let m = Meal(name: name); m.day = day; day.meals.append(m); modelContext.insert(m); return m
    }

    private func addTextEntry() {
        let m = findOrCreateMeal(name: selectedMealName)
        let e = MealEntry(type: .text, text: textEntry)
        e.meal = m; m.entries.append(e); modelContext.insert(e)
        textEntry = ""
    }

    private func addPhotoEntry() {
        guard let data = selectedImageData else { return }
        let filename = "meal_\(Int(Date().timeIntervalSince1970)).jpg"
        let url = saveImage(data: data, filename: filename)
        let m = findOrCreateMeal(name: selectedMealName)
        let e = MealEntry(type: .photo, photoLocalURL: url.absoluteString)
        e.meal = m; m.entries.append(e); modelContext.insert(e)
        selectedImageData = nil; selectedPhoto = nil
    }

    private func saveImage(data: Data, filename: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    private func analyzeToday() async {
        isAnalyzing = true; errorMessage = nil
        do {
            // 将今日所有文字条目拼接给模型做粗解析
            let texts = day.meals.flatMap { $0.entries }.compactMap { $0.type == .text ? $0.text : nil }
            let summary = try await AIService().parseDietText(texts: texts)
            await MainActor.run { day.analysis = summary }
        } catch { errorMessage = error.localizedDescription }
        isAnalyzing = false
    }
}