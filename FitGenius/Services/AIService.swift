import Foundation

struct ChatCompletionRequest: Codable {
	let model: String
	let messages: [Message]
	let stream: Bool?
	
	struct Message: Codable {
		let role: String
		let content: String
	}
	
	init(model: String, messages: [Message], stream: Bool? = nil) {
		self.model = model
		self.messages = messages
		self.stream = stream
	}
}

struct VisionChatCompletionRequest: Codable {
	let model: String
	let messages: [Message]
	let stream: Bool?
	
	struct Message: Codable {
		let role: String
		let content: [Content]
	}
	
	struct Content: Codable {
		let type: String
		let text: String?
		let image_url: ImageURL?
		let video_url: VideoURL?
        
        private enum CodingKeys: String, CodingKey {
            case type, text, image_url, video_url
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            if let text = text {
                try container.encode(text, forKey: .text)
            }
            if let image_url = image_url {
                try container.encode(image_url, forKey: .image_url)
            }
            if let video_url = video_url {
                try container.encode(video_url, forKey: .video_url)
            }
        }
	}
	
	struct ImageURL: Codable {
		let url: String
	}

    struct VideoURL: Codable {
        let url: String
    }
	
	init(model: String, messages: [Message], stream: Bool? = nil) {
		self.model = model
		self.messages = messages
		self.stream = stream
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

struct ChatCompletionStreamChunk: Codable {
	struct Choice: Codable {
		struct Delta: Codable {
			let content: String?
		}
		let delta: Delta
		let finish_reason: String?
	}
	let choices: [Choice]
}

// MARK: - AI 服务错误类型
enum AIServiceError: Error, LocalizedError {
    case backendNotConfigured
    case missingSessionToken
    case invalidURL
    case networkError(Error)
    case invalidResponse(String)
    case decodingError(Error)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "后端地址未配置,请联系开发者或重装 App"
        case .missingSessionToken:
            return NSLocalizedString("cloud_session_missing_error", comment: "")
        case .invalidURL:
            return "无效的 API URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "分析失败：\(message)"
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
    // Phase 2: 所有 AI 请求都强制走 FitGenius 后端代理。Aliyun API key
    // 只在 Vercel env 中存在,app bundle 不再持有任何 fallback key。
    private let textModel = AIModelRouting.textModel
    private let dietImageModel = AIModelRouting.dietImageModel
    private let fitnessImageModel = AIModelRouting.fitnessImageModel
    private let formSkeletonVisionModel = AIModelRouting.formSkeletonVisionModel
    private let settings: SyncSettings = .live
    private let languagePolicy = AppLanguagePolicy.current

    /// 解析请求目标 URL。**只**走后端代理;未配置 backendBaseURL 时返回
    /// nil 让调用方抛 `backendNotConfigured`。
    private func resolveRequestURL() -> URL? {
        let raw = settings.backendBaseURLString
        guard !raw.isEmpty else { return nil }
        return URL(string: raw + "/api/ai/chat")
    }

    /// 解析 Authorization header。**只**从 session token 解析;没有登录
    /// 拿到 session 就返回 nil,让调用方抛 `missingSessionToken`。
    private func resolveAuthHeader() -> String? {
        guard !settings.backendBaseURLString.isEmpty else { return nil }
        return settings.bearerToken.map { "Bearer \($0)" }
    }

    // Phase 2: AI 请求强制走后端代理,App 不再持有 Aliyun API key,
    // 也不再读取 Keychain / env / Config.plist / Info.plist。
    // 任何路径都解析失败时,直接抛对应的错误让调用方处理。

	private func sendStreamingRequest<T: Encodable>(body: T) async throws -> String {
		guard let authHeader = resolveAuthHeader() else {
			throw AIServiceError.missingSessionToken
		}
		guard let url = resolveRequestURL() else {
			throw AIServiceError.backendNotConfigured
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue(authHeader, forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let encoder = JSONEncoder()
		request.httpBody = try encoder.encode(body)
		let (bytes, response): (URLSession.AsyncBytes, URLResponse)
		do {
			(bytes, response) = try await URLSession.shared.bytes(for: request)
		} catch {
			throw AIServiceError.networkError(error)
		}
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            settings.setSessionToken(nil, userId: nil)
            throw AIServiceError.missingSessionToken
        }
		guard let httpResponse = response as? HTTPURLResponse,
				(200...299).contains(httpResponse.statusCode) else {
            var errorText = ""
            for try await line in bytes.lines {
                errorText += line
            }
            print("❌ [AIService] Error: \(errorText)")
			throw AIServiceError.invalidResponse(errorText.isEmpty ? "无效的服务器响应" : errorText)
		}
		var fullText = ""
		for try await line in bytes.lines {
			if line.hasPrefix("data: ") {
				let dataPart = String(line.dropFirst(6))
				if dataPart == "[DONE]" {
					break
				}
				guard let jsonData = dataPart.data(using: .utf8) else { continue }
				if let chunk = try? JSONDecoder().decode(ChatCompletionStreamChunk.self, from: jsonData),
					let delta = chunk.choices.first?.delta.content {
					fullText.append(delta)
				}
			}
		}
		let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			throw AIServiceError.emptyContent
		}
		return trimmed
	}
    
    // MARK: - 生成初始训练计划
	func generateInitialPlan(profile: UserProfile) async throws -> WorkoutPlan {
		print("🤖 [AIService] 开始生成训练计划...")
		print("🤖 [AIService] 用户信息：\(profile.name), \(profile.age)岁, 目标：\(profile.goal.rawValue)")

		// 验证请求目标 URL。Phase 2 强制走后端代理;没配 backendBaseURL
		// 时直接抛 backendNotConfigured 让用户知道这是个配置问题。
		guard resolveRequestURL() != nil else {
			throw AIServiceError.backendNotConfigured
		}
		// 验证 Authorization:必须登录拿到 session token,否则走兜底计划
		guard resolveAuthHeader() != nil else {
			print("⚠️ [AIService] 未登录，使用兜底训练计划")
			return fallbackPlan(for: profile)
		}

		print("✅ [AIService] 已登录，使用后端代理模式")
        
        let systemMessage = languagePolicy.initialPlanSystemPrompt
        let userMessage = profilePrompt(profile: profile, userRequest: nil)
        
        let requestBody = ChatCompletionRequest(
            model: textModel,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemMessage),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ],
            stream: true
        )
        let content = try await sendStreamingRequest(body: requestBody)
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
		// 验证 Authorization:未登录时走兜底计划
		guard resolveAuthHeader() != nil else {
			return fallbackPlan(for: profile)
		}
		
        let systemMessage = languagePolicy.regeneratePlanSystemPrompt
        let userMessage = profilePrompt(profile: profile, userRequest: userRequest)
        
		let requestBody = ChatCompletionRequest(
			model: textModel,
			messages: [
				ChatCompletionRequest.Message(role: "system", content: systemMessage),
				ChatCompletionRequest.Message(role: "user", content: userMessage)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
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
		// 序列化当前计划为 JSON（简化版）
        let planContext = serializePlanToContext(plan: plan, profile: profile)
        
        let systemMessage = """
        \(languagePolicy.chatSystemIntro)

        \(localizedProfileSummary(profile))

        \(languagePolicy.prefersSimplifiedChinese ? "当前训练计划：" : "Current training plan:")
        \(planContext)

        \(languagePolicy.prefersSimplifiedChinese ? "任务：" : "Tasks:")
        \(languagePolicy.prefersSimplifiedChinese ? "1. 如果用户只是普通聊天、咨询建议，直接返回文本回复。" : "1. If the user is asking for normal advice, return a normal text reply.")
        \(languagePolicy.prefersSimplifiedChinese ? "2. 如果用户想修改训练计划，必须返回下面的 JSON 格式。" : "2. If the user wants to modify the training plan, return the JSON format below.")

        \(languagePolicy.actionJSONExample)

        \(languagePolicy.prefersSimplifiedChinese ? "重要：如果返回 JSON，不要包含任何 Markdown 标记（如 ```json），只返回纯 JSON。" : "Important: if returning JSON, return raw JSON only. Do not include Markdown fences or explanatory text.")
        \(languagePolicy.responseLanguageInstruction)
        """
        
		let requestBody = ChatCompletionRequest(
			model: textModel,
			messages: [
				ChatCompletionRequest.Message(role: "system", content: systemMessage),
				ChatCompletionRequest.Message(role: "user", content: userMessage)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
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
        var context = languagePolicy.prefersSimplifiedChinese
            ? "计划名称：\(plan.name)\n"
            : "Plan name: \(plan.name)\n"
        context += languagePolicy.prefersSimplifiedChinese
            ? "训练天数：\((plan.days ?? []).count) 天\n\n"
            : "Training days: \((plan.days ?? []).count)\n\n"
        
        for day in (plan.days ?? []).sorted(by: { $0.dayNumber < $1.dayNumber }) {
            let focusName = languagePolicy.prefersSimplifiedChinese ? day.focus.rawValue : day.focus.localizedName
            context += languagePolicy.prefersSimplifiedChinese
                ? "第 \(day.dayNumber) 天 - \(focusName)：\n"
                : "Day \(day.dayNumber) - \(focusName):\n"
            for exercise in day.exercises ?? [] {
                context += languagePolicy.prefersSimplifiedChinese
                    ? "  - \(exercise.name): \(exercise.sets)组 x \(exercise.reps)"
                    : "  - \(exercise.name): \(exercise.sets) sets x \(exercise.reps)"
                if exercise.weight > 0 {
                    context += " @ \(exercise.weight)kg"
                }
                context += "\n"
            }
            context += "\n"
        }
        
        return context
    }

    private func profilePrompt(profile: UserProfile, userRequest: String?) -> String {
        let equipment = profile.availableEquipment.isEmpty
            ? languagePolicy.noValueText
            : profile.availableEquipment.joined(separator: ", ")
        let injuries = profile.injuries.isEmpty ? languagePolicy.noValueText : profile.injuries

        if languagePolicy.prefersSimplifiedChinese {
            var text = """
            用户信息：
            - 姓名：\(profile.name)
            - 年龄：\(profile.age)
            - 身高：\(profile.height) cm
            - 体重：\(profile.weight) kg
            - 健身目标：\(profile.goal.localizedName)
            - 训练环境：\(profile.environment.localizedName)
            - 可用器械：\(equipment)
            - 备注：\(injuries)
            """
            if let userRequest {
                text += "\n\n用户要求：\n\(userRequest)\n\n请根据用户要求重新生成训练计划。只返回 JSON，不要有任何其他文字。"
            } else {
                text += """

                请根据以上信息生成合适的训练计划。注意：
                1. 根据用户的年龄、目标和环境选择合适的循环天数（3/4/5/6/7天）
                2. 如果用户是新手或年龄较大，建议 3-4 天循环
                3. 如果用户目标是增肌且有充足时间，可以 5-7 天循环
                4. 必须包含至少一天休息日
                5. 根据可用器械选择合适的动作
                6. 如果备注中提到伤病，避免相关动作
                """
            }
            return text
        }

        var text = """
        User profile:
        - Name: \(profile.name)
        - Age: \(profile.age)
        - Height: \(profile.height) cm
        - Weight: \(profile.weight) kg
        - Fitness goal: \(profile.goal.localizedName)
        - Training environment: \(profile.environment.localizedName)
        - Available equipment: \(equipment)
        - Notes or limitations: \(injuries)
        """
        if let userRequest {
            text += "\n\nUser request:\n\(userRequest)\n\nRegenerate the training plan from the user's request. Return JSON only."
        } else {
            text += """

            Generate an appropriate training plan from this profile:
            1. Choose an appropriate cycle length (3/4/5/6/7 days) from age, goal, schedule, and environment.
            2. Use a 3-4 day cycle for beginners, older users, or users with limited recovery.
            3. Use a 5-7 day cycle only when the goal and context justify it.
            4. Include at least one rest day.
            5. Choose exercises that match the available equipment.
            6. Avoid exercises that conflict with notes or injuries.
            7. Keep every user-visible string in English.
            """
        }
        return text
    }

    private func localizedProfileSummary(_ profile: UserProfile) -> String {
        if languagePolicy.prefersSimplifiedChinese {
            return """
            当前用户信息：
            - 姓名：\(profile.name)
            - 年龄：\(profile.age)
            - 健身目标：\(profile.goal.localizedName)
            - 训练环境：\(profile.environment.localizedName)
            """
        }
        return """
        Current user profile:
        - Name: \(profile.name)
        - Age: \(profile.age)
        - Fitness goal: \(profile.goal.localizedName)
        - Training environment: \(profile.environment.localizedName)
        """
    }

    private func localizedMediaProfileSummary(_ profile: UserProfile) -> String {
        if languagePolicy.prefersSimplifiedChinese {
            return """
            用户信息：
            - 姓名：\(profile.name)
            - 年龄：\(profile.age) 岁
            - 目标：\(profile.goal.localizedName)
            - 训练环境：\(profile.environment.localizedName)
            """
        }
        return """
        User profile:
        - Name: \(profile.name)
        - Age: \(profile.age)
        - Goal: \(profile.goal.localizedName)
        - Training environment: \(profile.environment.localizedName)
        """
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
        let plan = WorkoutPlan(name: "fallback_plan_name".localized)
        plan.userProfile = profile
        
        // Day 1: 胸部
        let day1 = WorkoutDay(dayNumber: 1, focus: .chest, isRestDay: false)
        day1.plan = plan
        let ex1_1 = Exercise(name: "fallback_push_up".localized, sets: 4, reps: "12-15", weight: 0, notes: "fallback_keep_core_stable".localized)
        ex1_1.workoutDay = day1
        let ex1_2 = Exercise(name: "fallback_dumbbell_bench_press".localized, sets: 3, reps: "8-12", weight: 15, notes: "fallback_retract_shoulders".localized)
        ex1_2.workoutDay = day1
        day1.exercises = [ex1_1, ex1_2]
        
        // Day 2: 背部
        let day2 = WorkoutDay(dayNumber: 2, focus: .back, isRestDay: false)
        day2.plan = plan
        let ex2_1 = Exercise(name: "fallback_pull_up_lat_pulldown".localized, sets: 4, reps: "8-12", weight: 0)
        ex2_1.workoutDay = day2
        let ex2_2 = Exercise(name: "fallback_seated_row".localized, sets: 3, reps: "10-12", weight: 35)
        ex2_2.workoutDay = day2
        day2.exercises = [ex2_1, ex2_2]
        
        // Day 3: 腿部
        let day3 = WorkoutDay(dayNumber: 3, focus: .legs, isRestDay: false)
        day3.plan = plan
        let ex3_1 = Exercise(name: "fallback_squat_leg_press".localized, sets: 4, reps: "8-12", weight: 40)
        ex3_1.workoutDay = day3
        let ex3_2 = Exercise(name: "fallback_lunge".localized, sets: 3, reps: "12-15", weight: 0)
        ex3_2.workoutDay = day3
        day3.exercises = [ex3_1, ex3_2]
        
        // Day 4: 休息日
        let day4 = WorkoutDay(dayNumber: 4, focus: .rest, isRestDay: true)
        day4.plan = plan
        
        plan.days = [day1, day2, day3, day4]
        return plan
    }

	func dietChat(userMessage: String) async throws -> String {
		let systemMessage = languagePolicy.dietCoachSystemPrompt
		let requestBody = ChatCompletionRequest(
			model: textModel,
			messages: [
				ChatCompletionRequest.Message(role: "system", content: systemMessage),
			ChatCompletionRequest.Message(role: "user", content: userMessage)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
		return content.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	func dietChatWithImages(userMessage: String, images: [Data]) async throws -> String {
		var userContents: [VisionChatCompletionRequest.Content] = []
		let intro = VisionChatCompletionRequest.Content(
			type: "text",
			text: languagePolicy.dietImageCoachPrompt,
			image_url: nil,
			video_url: nil
		)
		userContents.append(intro)
		let question = VisionChatCompletionRequest.Content(type: "text", text: userMessage, image_url: nil, video_url: nil)
		userContents.append(question)
		for data in images {
			let base64 = data.base64EncodedString()
			let urlString = "data:image/jpeg;base64,\(base64)"
			let imageURL = VisionChatCompletionRequest.ImageURL(url: urlString)
			let content = VisionChatCompletionRequest.Content(type: "image_url", text: nil, image_url: imageURL, video_url: nil)
			userContents.append(content)
		}
		let requestBody = VisionChatCompletionRequest(
			model: dietImageModel,
			messages: [
				VisionChatCompletionRequest.Message(
					role: "system",
					content: [VisionChatCompletionRequest.Content(type: "text", text: languagePolicy.dietCoachSystemPrompt, image_url: nil, video_url: nil)]
				),
				VisionChatCompletionRequest.Message(
					role: "user",
					content: userContents
				)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
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
		let systemMessage = languagePolicy.dietAnalyzeSystemPrompt
		var description = languagePolicy.prefersSimplifiedChinese
            ? "当天饮食记录（共" + String(entries.count) + "条）：\n"
            : "Meal records for today (\(entries.count) total):\n"
		for (index, e) in entries.enumerated() {
			if languagePolicy.prefersSimplifiedChinese {
				description += "\(index+1). 餐次=\(e.mealType.rawValue)，描述=\(e.text.isEmpty ? languagePolicy.noValueText : e.text)\n"
			} else {
				description += "\(index+1). mealType=\(e.mealType.rawValue), description=\(e.text.isEmpty ? languagePolicy.noValueText : e.text)\n"
			}
		}
		let requestBody = ChatCompletionRequest(
			model: textModel,
			messages: [
				ChatCompletionRequest.Message(role: "system", content: systemMessage),
			ChatCompletionRequest.Message(role: "user", content: description)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
		let cleaned = cleanMarkdownCodeBlock(content)
        guard let jsonData = cleaned.data(using: .utf8) else { throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1)) }
        return try JSONDecoder().decode(DietAnalyzeResponse.self, from: jsonData)
    }

	func analyzeMealsWithImages(entries: [MealEntry]) async throws -> DietAnalyzeResponse {
        var description = languagePolicy.prefersSimplifiedChinese ? "当天饮食记录：\n" : "Meal records for today:\n"
        for (index, e) in entries.enumerated() {
            if languagePolicy.prefersSimplifiedChinese {
                description += "\(index+1). 餐次=\(e.mealType.rawValue)，描述=\(e.text.isEmpty ? languagePolicy.noValueText : e.text)\n"
            } else {
                description += "\(index+1). mealType=\(e.mealType.rawValue), description=\(e.text.isEmpty ? languagePolicy.noValueText : e.text)\n"
            }
        }
        var userContents: [VisionChatCompletionRequest.Content] = []
        let textContent = VisionChatCompletionRequest.Content(type: "text", text: languagePolicy.dietImageAnalyzePrompt, image_url: nil, video_url: nil)
        userContents.append(textContent)
        let descContent = VisionChatCompletionRequest.Content(type: "text", text: description, image_url: nil, video_url: nil)
        userContents.append(descContent)
		for entry in entries {
			for data in entry.images {
				let base64 = data.base64EncodedString()
				let urlString = "data:image/jpeg;base64,\(base64)"
				let imageURL = VisionChatCompletionRequest.ImageURL(url: urlString)
				let content = VisionChatCompletionRequest.Content(type: "image_url", text: nil, image_url: imageURL, video_url: nil)
				userContents.append(content)
			}
		}
		let requestBody = VisionChatCompletionRequest(
			model: dietImageModel,
			messages: [
				VisionChatCompletionRequest.Message(
					role: "system",
					content: [VisionChatCompletionRequest.Content(type: "text", text: languagePolicy.dietAnalyzeSystemPrompt, image_url: nil, video_url: nil)]
				),
				VisionChatCompletionRequest.Message(
					role: "user",
					content: userContents
				)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
		let cleaned = cleanMarkdownCodeBlock(content)
        guard let jsonData = cleaned.data(using: .utf8) else { throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1)) }
        return try JSONDecoder().decode(DietAnalyzeResponse.self, from: jsonData)
    }

    func enrichFormFeedback(
        summary: FormAnalysisSummary,
        skeletonImages: [Data],
        feedbackTimestamp: Double
    ) async throws -> FormCoachEnrichmentResult {
        guard !skeletonImages.isEmpty else {
            throw AIServiceError.invalidResponse("No skeleton frames")
        }

        var userContents: [VisionChatCompletionRequest.Content] = [
            VisionChatCompletionRequest.Content(
                type: "text",
                text: formCoachPromptSummary(summary: summary, feedbackTimestamp: feedbackTimestamp),
                image_url: nil,
                video_url: nil
            )
        ]

        for imageData in skeletonImages {
            let imageURL = VisionChatCompletionRequest.ImageURL(
                url: "data:image/jpeg;base64,\(imageData.base64EncodedString())"
            )
            userContents.append(VisionChatCompletionRequest.Content(
                type: "image_url",
                text: nil,
                image_url: imageURL,
                video_url: nil
            ))
        }

        let requestBody = VisionChatCompletionRequest(
            model: formSkeletonVisionModel,
            messages: [
                VisionChatCompletionRequest.Message(
                    role: "system",
                    content: [VisionChatCompletionRequest.Content(
                        type: "text",
                        text: languagePolicy.formCoachEnrichmentSystemPrompt,
                        image_url: nil,
                        video_url: nil
                    )]
                ),
                VisionChatCompletionRequest.Message(role: "user", content: userContents)
            ],
            stream: true
        )
        let content = try await sendStreamingRequest(body: requestBody)
        let cleaned = cleanMarkdownCodeBlock(content)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AIServiceError.decodingError(NSError(domain: "AIService", code: -1))
        }
        return try JSONDecoder().decode(FormCoachEnrichmentResult.self, from: jsonData)
    }

    private func formCoachPromptSummary(
        summary: FormAnalysisSummary,
        feedbackTimestamp: Double
    ) -> String {
        let metrics = summary.metrics.map { metric in
            "- \(metric.key): \(metric.label)=\(String(format: "%.2f", metric.value)) \(metric.unit)"
        }.joined(separator: "\n")
        let issues = summary.issues.isEmpty
            ? (languagePolicy.prefersSimplifiedChinese ? "未检测到主要问题" : "No major issue detected")
            : summary.issues.map { "- [\($0.severity)] \($0.code): \($0.title) - \($0.detail)" }.joined(separator: "\n")
        if languagePolicy.prefersSimplifiedChinese {
            return """
            动作：\(summary.exerciseType.displayName)
            本地规则评分：\(summary.score)
            关键帧时间：\(String(format: "%.1f", feedbackTimestamp)) 秒
            本地指标：
            \(metrics)
            本地检测问题：
            \(issues)
            本地建议：\(summary.recommendation)
            骨架图片顺序：image_index 从 0 开始，表示同一段动作的不同关键时刻。请不要否定本地规则，只基于这些骨架图补充教学解释。
            """
        }
        return """
        Exercise: \(summary.exerciseType.displayName)
        On-device rule score: \(summary.score)
        Key-frame time: \(String(format: "%.1f", feedbackTimestamp)) s
        On-device metrics:
        \(metrics)
        On-device detected issues:
        \(issues)
        On-device recommendation: \(summary.recommendation)
        Skeleton image order: image_index starts at 0 and represents key moments in the same clip. Do not contradict the on-device rule result; enrich it with coaching explanation only.
        """
    }

	func analyzeFitnessMedia(userMessage: String, profile: UserProfile, plan: WorkoutPlan?, images: [Data], videos: [Data]) async throws -> String {
        let mediaModel = videos.isEmpty ? fitnessImageModel : textModel
		var systemContents: [VisionChatCompletionRequest.Content] = []
        let systemText = languagePolicy.fitnessMediaSystemPrompt
        let systemContent = VisionChatCompletionRequest.Content(type: "text", text: systemText, image_url: nil, video_url: nil)
        systemContents.append(systemContent)
        var userContents: [VisionChatCompletionRequest.Content] = []
        let profileText = localizedMediaProfileSummary(profile)
        let profileContent = VisionChatCompletionRequest.Content(type: "text", text: profileText, image_url: nil, video_url: nil)
        userContents.append(profileContent)
        if let plan = plan {
            let planContext = serializePlanToContext(plan: plan, profile: profile)
            let title = languagePolicy.prefersSimplifiedChinese ? "当前训练计划：" : "Current training plan:"
            let planContent = VisionChatCompletionRequest.Content(type: "text", text: "\(title)\n\(planContext)", image_url: nil, video_url: nil)
            userContents.append(planContent)
        }
        let questionContent = VisionChatCompletionRequest.Content(type: "text", text: userMessage, image_url: nil, video_url: nil)
        userContents.append(questionContent)
        for data in images {
            let base64 = data.base64EncodedString()
            let urlString = "data:image/jpeg;base64,\(base64)"
            let imageURL = VisionChatCompletionRequest.ImageURL(url: urlString)
            let content = VisionChatCompletionRequest.Content(type: "image_url", text: nil, image_url: imageURL, video_url: nil)
            userContents.append(content)
        }
        for data in videos {
            // 智能压缩：如果大于 10MB，尝试压缩 (API 通常限制 payload 大小)
            var finalData = data
            // 只要大于 10MB 就尝试压缩，因为 Base64 编码会增加 33% 体积
            if finalData.count > 10 * 1024 * 1024 {
                print("Video size \(finalData.count / 1024 / 1024)MB > 10MB, compressing...")
                do {
                    // 尝试压缩到 15MB 以内 (Base64 后约 20MB)
                    finalData = try await VideoCompressor.compressVideo(data: finalData, maxSizeBytes: 15 * 1024 * 1024)
                } catch {
                    print("Compression failed: \(error), proceeding with original data")
                }
            }
            
            // 硬性拦截：如果压缩后依然超过 20MB (Base64 后约 26MB)，大概率会被 API 拒绝
            // 为了用户体验，我们设定一个合理的上限
            let limit = 20 * 1024 * 1024
            if finalData.count > limit {
                 throw AIServiceError.networkError(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频压缩后仍然过大（\(finalData.count / 1024 / 1024)MB），请上传较短的视频（建议 30 秒以内）。"]))
            }
            
            let base64 = finalData.base64EncodedString()
            let urlString = "data:video/mp4;base64,\(base64)"
            let videoURL = VisionChatCompletionRequest.VideoURL(url: urlString)
            let content = VisionChatCompletionRequest.Content(type: "video_url", text: nil, image_url: nil, video_url: videoURL)
            userContents.append(content)
        }
		let requestBody = VisionChatCompletionRequest(
			model: mediaModel,
			messages: [
				VisionChatCompletionRequest.Message(role: "system", content: systemContents),
				VisionChatCompletionRequest.Message(role: "user", content: userContents)
			],
			stream: true
		)
		let content = try await sendStreamingRequest(body: requestBody)
		return content.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
