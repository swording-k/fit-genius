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
    
    // 从环境变量读取 API Key
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["ALIYUN_API_KEY"]
    }
    
    // MARK: - 生成初始训练计划
    func generateInitialPlan(profile: UserProfile) async throws -> WorkoutPlan {
        // 验证 API Key
        guard let apiKey = apiKey else {
            throw AIServiceError.missingAPIKey
        }
        
        // 验证 URL
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        // 构建 Prompt
        let systemMessage = """
        你是一个专业的健身教练。请根据用户数据生成 JSON 格式的训练计划。
        
        要求：
        1. 不要返回任何 Markdown 标记（如 ```json），只返回纯 JSON 字符串
        2. JSON 结构必须包含：name (计划名称), days (训练日数组)
        3. 每个 day 包含：dayNumber (第几天), focus (重点部位), exercises (动作数组)
        4. 每个 exercise 包含：name (动作名称), sets (组数), reps (次数范围如"8-12"), weight (建议重量), notes (备注)
        5. 重点部位必须是以下之一：胸部、背部、腿部、肩部、手臂、核心、全身、有氧
        6. 所有内容都使用中文
        
        示例 JSON 格式：
        {
          "name": "增肌训练计划",
          "days": [
            {
              "dayNumber": 1,
              "focus": "胸部",
              "exercises": [
                {
                  "name": "杠铃卧推",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 60,
                  "notes": "注意肩胛骨收紧"
                }
              ]
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
        - 伤病情况：\(profile.injuries.isEmpty ? "无" : profile.injuries)
        
        请为该用户生成一个为期 5-7 天的训练计划。只返回 JSON，不要有任何其他文字。
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
        
        // 解析为 WorkoutPlan
        return try parseWorkoutPlan(from: cleanedContent, profile: profile)
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
        context += "训练天数：\(plan.days.count) 天\n\n"
        
        for day in plan.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            context += "第 \(day.dayNumber) 天 - \(day.focus.rawValue)：\n"
            for exercise in day.exercises {
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
                let exercises: [ExerciseJSON]
                
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
            print("🔍 解析部位: \(dayJSON.focus)")
            let focus = BodyPartFocus(rawValue: dayJSON.focus) ?? .fullBody
            print("✅ 解析结果: \(focus.rawValue)")
            
            let workoutDay = WorkoutDay(dayNumber: dayJSON.dayNumber, focus: focus)
            workoutDay.plan = workoutPlan
            
            // 创建 Exercise
            for exerciseJSON in dayJSON.exercises {
                let exercise = Exercise(
                    name: exerciseJSON.name,
                    sets: exerciseJSON.sets,
                    reps: exerciseJSON.reps,
                    weight: exerciseJSON.weight,
                    notes: exerciseJSON.notes ?? ""
                )
                exercise.workoutDay = workoutDay
                workoutDay.exercises.append(exercise)
            }
            
            workoutPlan.days.append(workoutDay)
        }
        
        print("✅ 训练计划创建成功，共 \(workoutPlan.days.count) 天")
        return workoutPlan
    }
}
