import Foundation

// MARK: - API 请求和响应模型
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - AI 服务错误类型
enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case emptyContent
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key，请在环境变量中设置 ALIYUN_API_KEY"
        case .invalidURL:
            return "无效的 API URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的服务器响应"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .emptyContent:
            return "AI 返回的内容为空"
        }
    }
}

// MARK: - AI 服务类
@MainActor
class AIService {
    // 阿里云 OpenAI 兼容接口
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let model = "qwen-plus"
    
    // 从 Keychain / 环境变量 / 配置文件读取 API Key
    private var apiKey: String? {
        if let key = Keychain.read("aliyun_api_key"), !key.isEmpty {
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["ALIYUN_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let key = config["ALIYUN_API_KEY"] as? String,
           !key.isEmpty && key != "YOUR_API_KEY_HERE" {
            return key
        }
        if let infoKey = Bundle.main.infoDictionary?["ALIYUN_API_KEY"] as? String,
           !infoKey.isEmpty && infoKey != "YOUR_API_KEY_HERE" {
            return infoKey
        }
        return nil
    }
    
    // MARK: - 生成初始训练计划
    func generateInitialPlan(profile: UserProfile) async throws -> WorkoutPlan {
        print("🤖 [AIService] 开始生成训练计划...")
        print("🤖 [AIService] 用户信息：\(profile.name), \(profile.age)岁, 目标：\(profile.goal.rawValue)")
        
        // 验证 API Key（没有则返回本地兜底计划）
        guard let apiKey = apiKey else {
            print("⚠️ [AIService] 未找到 API Key，使用兜底计划")
            return fallbackPlan(for: profile)
        }
        
        print("✅ [AIService] API Key 已配置")
        
        // 验证 URL
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        // 构建 Prompt
        let systemMessage = """
        你是一个专业的健身教练。请根据用户数据生成 JSON 格式的训练计划。
        
        重要：根据用户情况选择合适的训练分化和循环天数：
        
        1. 新手/时间少：3-4天循环
           - 3天：全身训练 + 休息（Day1:全身 → Day2:休息 → Day3:全身 → Day4:休息）
           - 4天：推拉腿 + 休息（Day1:推 → Day2:拉 → Day3:腿 → Day4:休息）
        
        2. 中级/时间适中：4-5天循环
           - 4天：推拉腿 + 休息
           - 5天：上下肢分化 + 休息（Day1:上肢推 → Day2:下肢 → Day3:上肢拉 → Day4:休息 → Day5:全身）
        
        3. 高级/时间充足：6-7天循环
           - 6天：5天分化 + 1休息（Day1:胸 → Day2:背 → Day3:腿 → Day4:肩 → Day5:手臂 → Day6:休息）
           - 7天：6天分化 + 1休息
        
        JSON 格式要求：
        1. 不要返回任何 Markdown 标记（如 ```json），只返回纯 JSON 字符串
        2. 必须包含：name (计划名称), days (训练日数组)
        3. 每个 day 包含：
           - dayNumber: 第几天（1, 2, 3...）
           - focus: 重点部位（胸部、背部、腿部、肩部、手臂、核心、全身、有氧、休息）
           - isRestDay: 是否休息日（true/false）
           - exercises: 动作数组（休息日为空数组）
        4. 每个 exercise 包含：name, sets, reps, weight, notes
        5. 所有内容使用中文
        
        示例 JSON（4天循环）：
        {
          "name": "推拉腿训练计划",
          "days": [
            {
              "dayNumber": 1,
              "focus": "胸部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "杠铃卧推",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 60,
                  "notes": "注意肩胛骨收紧"
                }
              ]
            },
            {
              "dayNumber": 2,
              "focus": "背部",
              "isRestDay": false,
              "exercises": []
            },
            {
              "dayNumber": 3,
              "focus": "腿部",
              "isRestDay": false,
              "exercises": []
            },
            {
              "dayNumber": 4,
              "focus": "休息",
              "isRestDay": true,
              "exercises": []
            }
          ]
        }
        """
        
        let userMessage = """
        用户信息：
        - 姓名：\(profile.name)
        - 年龄：\(profile.age)
        - 身高：\(profile.height) cm
        - 体重：\(profile.weight) kg
        - 健身目标：\(profile.goal.rawValue)
        - 训练环境：\(profile.environment.rawValue)
        - 可用器械：\(profile.availableEquipment.isEmpty ? "无" : profile.availableEquipment.joined(separator: ", "))
        - 备注：\(profile.injuries.isEmpty ? "无" : profile.injuries)
        
        请根据以上信息生成合适的训练计划。注意：
        1. 根据用户的年龄、目标和环境选择合适的循环天数（3/4/5/6/7天）
        2. 如果用户是新手或年龄较大，建议 3-4 天循环
        3. 如果用户目标是增肌且有充足时间，可以 5-7 天循环
        4. 必须包含至少一天休息日
        5. 根据可用器械选择合适的动作
        6. 如果备注中提到伤病，避免相关动作
        """
        
        // 构建请求体
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ]
        )
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 发送请求
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.networkError(error)
        }
        
        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }
        
        // 解析响应
        let chatResponse: ChatCompletionResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 获取内容
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIServiceError.emptyContent
        }
        
        // 清理 Markdown 标记
        let cleanedContent = cleanMarkdownCodeBlock(content)
        
        // 解析为 WorkoutPlan；解析失败时使用本地兜底计划
        do {
            return try parseWorkoutPlan(from: cleanedContent, profile: profile)
        } catch {
            return fallbackPlan(for: profile)
        }
    }
    
    // MARK: - 根据用户要求重新生成训练计划
    func regeneratePlan(profile: UserProfile, userRequest: String) async throws -> WorkoutPlan {
        // 验证 API Key（没有则返回本地兜底计划）
        guard let apiKey = apiKey else {
            return fallbackPlan(for: profile)
        }
        
        // 验证 URL
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        // 构建 Prompt
        let systemMessage = """
        你是一个专业的健身教练。用户想要修改训练计划的整体结构。
        
        请根据用户的要求重新生成完整的训练计划。
        
        **重要：根据用户要求选择合适的训练分化和循环天数**
        
        1. 新手/时间少：3-4天循环
           - 3天：全身训练 + 休息
           - 4天：推拉腿 + 休息
        
        2. 中级/时间适中：4-5天循环
           - 4天：推拉腿 + 休息
           - 5天：上下肢分化 + 休息
        
        3. 高级/时间充足：6-7天循环
           - 6天：5天分化 + 1休息
           - 7天：6天分化 + 1休息
        
        **JSON 格式要求（非常重要）**：
        1. 只返回纯 JSON，不要有任何 Markdown 标记（如 ```json）
        2. 不要有任何解释性文字，只返回 JSON
        3. 必须包含：name, days
        4. 每个 day 必须包含：dayNumber, focus, isRestDay, exercises
        5. 休息日必须设置：isRestDay: true, exercises: []
        6. 训练日必须设置：isRestDay: false
        7. 所有字符串使用中文
        
        **完整示例（4天循环：胸背肩腿）**：
        {
          "name": "四分化训练计划",
          "days": [
            {
              "dayNumber": 1,
              "focus": "胸部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "杠铃卧推",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 60.0,
                  "notes": "注意肩胛骨收紧"
                },
                {
                  "name": "哑铃飞鸟",
                  "sets": 3,
                  "reps": "10-15",
                  "weight": 15.0,
                  "notes": "顶峰收缩"
                }
              ]
            },
            {
              "dayNumber": 2,
              "focus": "背部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "引体向上",
                  "sets": 4,
                  "reps": "6-10",
                  "weight": 0.0,
                  "notes": "可以使用辅助"
                }
              ]
            },
            {
              "dayNumber": 3,
              "focus": "肩部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "哑铃推举",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 20.0,
                  "notes": "保持核心稳定"
                }
              ]
            },
            {
              "dayNumber": 4,
              "focus": "腿部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "深蹲",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 80.0,
                  "notes": "膝盖不要超过脚尖"
                }
              ]
            },
            {
              "dayNumber": 5,
              "focus": "休息",
              "isRestDay": true,
              "exercises": []
            }
          ]
        }
        
        请严格按照上述格式返回 JSON，不要有任何其他内容。
        """
        
        let userMessage = """
        用户信息：
        - 姓名：\(profile.name)
        - 年龄：\(profile.age)
        - 身高：\(profile.height) cm
        - 体重：\(profile.weight) kg
        - 健身目标：\(profile.goal.rawValue)
        - 训练环境：\(profile.environment.rawValue)
        - 可用器械：\(profile.availableEquipment.isEmpty ? "无" : profile.availableEquipment.joined(separator: ", "))
        - 备注：\(profile.injuries.isEmpty ? "无" : profile.injuries)
        
        用户要求：
        \(userRequest)
        
        请根据用户要求重新生成训练计划。只返回 JSON，不要有任何其他文字。
        """
        
        // 构建请求体
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ]
        )
        
        // 发送请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }
        
        // 解析响应
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIServiceError.emptyContent
        }
        
        // 清理 Markdown 标记
        let cleanedContent = cleanMarkdownCodeBlock(content)
        
        // 解析 JSON 并创建 WorkoutPlan；解析失败时使用本地兜底计划
        do {
            return try parseWorkoutPlan(from: cleanedContent, profile: profile)
        } catch {
            return fallbackPlan(for: profile)
        }
    }
    
    // MARK: - AI 助手对话（支持计划修改）
    func chat(userMessage: String, profile: UserProfile, plan: WorkoutPlan) async throws -> (response: String, command: AIActionCommand?) {
        // 验证 API Key
        guard let apiKey = apiKey else {
            throw AIServiceError.missingAPIKey
        }
        
        // 验证 URL
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        // 序列化当前计划为 JSON（简化版）
        let planContext = serializePlanToContext(plan: plan, profile: profile)
        
        // 构建 System Prompt
        let systemMessage = """
        你是一个专业的健身教练 AI 助手。你正在帮助用户管理他们的训练计划。
        
        当前用户信息：
        - 姓名：\(profile.name)
        - 年龄：\(profile.age)
        - 健身目标：\(profile.goal.rawValue)
        - 训练环境：\(profile.environment.rawValue)
        
        当前训练计划：
        \(planContext)
        
        你的任务：
        1. 如果用户只是普通聊天、咨询建议，直接返回文本回复。
        2. 如果用户想修改训练计划（例如："把深蹲换掉"、"我膝盖疼，调整一下"、"增加一个动作"），你必须返回以下 JSON 格式：
        
        {
          "type": "update_plan",
          "actions": [
            {
              "day": 1,
              "old_exercise": "深蹲",
              "new_exercise": "腿屈伸",
              "sets": 4,
              "reps": "12-15",
              "weight": 40,
              "reason": "膝盖友好的替代动作"
            }
          ]
        }
        
        JSON 字段说明：
        - type: "update_plan" (修改计划) 或 "add_exercise" (添加动作) 或 "remove_exercise" (删除动作)
        - day: 第几天（1-7）
        - old_exercise: 要替换的旧动作名称（仅 update_plan 需要）
        - new_exercise: 新动作名称（update_plan 和 add_exercise 需要）
        - exercise_name: 要删除的动作名称（仅 remove_exercise 需要）
        - sets, reps, weight: 新动作的参数
        - reason: 修改原因
        
        重要：如果返回 JSON，不要包含任何 Markdown 标记（如 ```json），只返回纯 JSON。
        """
        
        // 构建请求体
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ]
        )
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 发送请求
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.networkError(error)
        }
        
        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }
        
        // 解析响应
        let chatResponse: ChatCompletionResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 获取内容
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIServiceError.emptyContent
        }
        
        // 清理 Markdown 标记
        let cleanedContent = cleanMarkdownCodeBlock(content)
        
        // 尝试解析为 JSON 指令
        if let command = try? parseActionCommand(from: cleanedContent) {
            // 返回空字符串和指令（不显示 JSON 给用户）
            return ("", command)
        } else {
            // 普通文本回复
            return (cleanedContent, nil)
        }
    }
    
    // MARK: - 序列化计划为 Context
    private func serializePlanToContext(plan: WorkoutPlan, profile: UserProfile) -> String {
        var context = "计划名称：\(plan.name)\n"
        context += "训练天数：\((plan.days ?? []).count) 天\n\n"
        
        for day in (plan.days ?? []).sorted(by: { $0.dayNumber < $1.dayNumber }) {
            context += "第 \(day.dayNumber) 天 - \(day.focus.rawValue)：\n"
            for exercise in day.exercises ?? [] {
                context += "  - \(exercise.name): \(exercise.sets)组 x \(exercise.reps)"
                if exercise.weight > 0 {
                    context += " @ \(exercise.weight)kg"
                }
                context += "\n"
            }
            context += "\n"
        }
        
        return context
    }
    
    // MARK: - 解析 AI 操作指令
    private func parseActionCommand(from jsonString: String) throws -> AIActionCommand {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1))
        }
        
        return try JSONDecoder().decode(AIActionCommand.self, from: jsonData)
    }
    
    // MARK: - 辅助方法：清理 Markdown 代码块标记
    private func cleanMarkdownCodeBlock(_ content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除开头的 ```json 或 ```
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        // 移除结尾的 ```
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 辅助方法：解析 JSON 为 WorkoutPlan
    private func parseWorkoutPlan(from jsonString: String, profile: UserProfile) throws -> WorkoutPlan {
        // 定义临时解析结构
        struct PlanJSON: Codable {
            let name: String
            let days: [DayJSON]
            
            struct DayJSON: Codable {
                let dayNumber: Int
                let focus: String
                let isRestDay: Bool?  // 可选字段
                let exercises: [ExerciseJSON]?
                
                struct ExerciseJSON: Codable {
                    let name: String
                    let sets: Int
                    let reps: String
                    let weight: Double
                    let notes: String?
                }
            }
        }
        
        // 打印原始 JSON 用于调试
        print("📝 收到的 JSON 字符串:")
        print(jsonString)
        
        // 解析 JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法将字符串转换为 Data"]))
        }
        
        let planJSON: PlanJSON
        do {
            planJSON = try JSONDecoder().decode(PlanJSON.self, from: jsonData)
            print("✅ JSON 解析成功")
        } catch {
            print("❌ JSON 解析失败: \(error)")
            print("JSON 内容: \(jsonString)")
            throw AIServiceError.decodingError(error)
        }
        
        // 创建 WorkoutPlan
        let workoutPlan = WorkoutPlan(name: planJSON.name)
        workoutPlan.userProfile = profile
        
        // 创建 WorkoutDay 和 Exercise
        for dayJSON in planJSON.days {
            // 解析 focus
            print("🔍 解析部位: \(dayJSON.focus), isRestDay: \(dayJSON.isRestDay ?? false)")
            
            // 如果是休息日，强制设置 focus 为 .rest
            let focus: BodyPartFocus
            let isRestDay = dayJSON.isRestDay ?? false
            
            if isRestDay || dayJSON.focus == "休息" || dayJSON.focus == "休息日" {
                focus = .rest
            } else {
                focus = BodyPartFocus(rawValue: dayJSON.focus) ?? .fullBody
            }
            
            print("✅ 解析结果: \(focus.rawValue), isRestDay: \(isRestDay)")
            
            let workoutDay = WorkoutDay(dayNumber: dayJSON.dayNumber, focus: focus, isRestDay: isRestDay)
            workoutDay.plan = workoutPlan
            
            // 解析动作
            if let exercisesJSON = dayJSON.exercises {
                for exerciseJSON in exercisesJSON {
                    let exercise = Exercise(
                        name: exerciseJSON.name,
                        sets: exerciseJSON.sets,
                        reps: exerciseJSON.reps,
                        weight: exerciseJSON.weight,
                        notes: exerciseJSON.notes ?? ""
                    )
                    exercise.workoutDay = workoutDay
                    
                    if workoutDay.exercises == nil {
                        workoutDay.exercises = []
                    }
                    workoutDay.exercises?.append(exercise)
                }
            }
            
            if workoutPlan.days == nil {
                workoutPlan.days = []
            }
            workoutPlan.days?.append(workoutDay)
        }
        
        print("✅ 训练计划创建成功，共 \((workoutPlan.days ?? []).count) 天")
        return workoutPlan
    }

    private func fallbackPlan(for profile: UserProfile) -> WorkoutPlan {
        let plan = WorkoutPlan(name: "基础训练计划")
        plan.userProfile = profile
        
        // Day 1: 胸部
        let day1 = WorkoutDay(dayNumber: 1, focus: .chest, isRestDay: false)
        day1.plan = plan
        let ex1_1 = Exercise(name: "俯卧撑", sets: 4, reps: "12-15", weight: 0, notes: "保持核心稳定")
        ex1_1.workoutDay = day1
        let ex1_2 = Exercise(name: "哑铃卧推", sets: 3, reps: "8-12", weight: 15, notes: "肩胛收紧")
        ex1_2.workoutDay = day1
        day1.exercises = [ex1_1, ex1_2]
        
        // Day 2: 背部
        let day2 = WorkoutDay(dayNumber: 2, focus: .back, isRestDay: false)
        day2.plan = plan
        let ex2_1 = Exercise(name: "引体向上/高位下拉", sets: 4, reps: "8-12", weight: 0)
        ex2_1.workoutDay = day2
        let ex2_2 = Exercise(name: "坐姿划船", sets: 3, reps: "10-12", weight: 35)
        ex2_2.workoutDay = day2
        day2.exercises = [ex2_1, ex2_2]
        
        // Day 3: 腿部
        let day3 = WorkoutDay(dayNumber: 3, focus: .legs, isRestDay: false)
        day3.plan = plan
        let ex3_1 = Exercise(name: "深蹲/腿举", sets: 4, reps: "8-12", weight: 40)
        ex3_1.workoutDay = day3
        let ex3_2 = Exercise(name: "弓步蹲", sets: 3, reps: "12-15", weight: 0)
        ex3_2.workoutDay = day3
        day3.exercises = [ex3_1, ex3_2]
        
        // Day 4: 休息日
        let day4 = WorkoutDay(dayNumber: 4, focus: .rest, isRestDay: true)
        day4.plan = plan
        
        plan.days = [day1, day2, day3, day4]
        return plan
    }

    func dietChat(userMessage: String) async throws -> String {
        guard let apiKey = apiKey else { throw AIServiceError.missingAPIKey }
        guard let url = URL(string: baseURL) else { throw AIServiceError.invalidURL }
        let systemMessage = "你是一个专业的营养与饮食顾问。为用户提供饮食建议、营养科普，并可帮助规范化他们的饮食记录。回答使用中文，简洁可读。"
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw AIServiceError.invalidResponse }
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else { throw AIServiceError.emptyContent }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct DietAnalyzeResponse: Codable {
        struct Item: Codable {
            let name: String
            let portion: Double
            let unit: String
            let calories: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let notes: String?
            let mealType: String
        }
        struct Summary: Codable {
            let totalCalories: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let notes: String?
        }
        let entries: [Item]
        let summary: Summary
    }

    func analyzeMeals(entries: [MealEntry]) async throws -> DietAnalyzeResponse {
        guard let apiKey = apiKey else { throw AIServiceError.missingAPIKey }
        guard let url = URL(string: baseURL) else { throw AIServiceError.invalidURL }
        let systemMessage = """
        你是一个专业的营养师。请严格按照下述要求解析用户当天饮食：
        
        1) 仅返回纯 JSON（不包含任何 Markdown 代码块或解释性文字）
        2) 数组 entries 的长度必须与用户输入的条目数完全一致，并与输入顺序一一对应
        3) 每个条目的单位统一为：portion 使用克(g)，calories 使用千卡(kcal)
        4) 每个 entries[i] 必须包含字段：name, portion, unit, calories, protein, carbs, fat, notes, mealType
        5) summary 字段必须包含：totalCalories, protein, carbs, fat, notes
        6) 若用户描述中为“一碗/一盘/一勺”等量词，请合理估算并换算为克(g)
        7) 所有返回内容使用中文。
        """
        var description = "当天饮食记录（共" + String(entries.count) + "条）：\n"
        for (index, e) in entries.enumerated() {
            description += "\(index+1). 餐次=\(e.mealType.rawValue)，描述=\(e.text.isEmpty ? "无" : e.text)\n"
        }
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: description)
            ]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw AIServiceError.invalidResponse }
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else { throw AIServiceError.emptyContent }
        let cleaned = cleanMarkdownCodeBlock(content)
        guard let jsonData = cleaned.data(using: .utf8) else { throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1)) }
        return try JSONDecoder().decode(DietAnalyzeResponse.self, from: jsonData)
    }
}
