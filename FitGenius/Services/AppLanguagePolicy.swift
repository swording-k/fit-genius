import Foundation

struct AppLanguagePolicy {
    let preferredLanguageIdentifier: String

    static var current: AppLanguagePolicy {
        AppLanguagePolicy(
            preferredLanguageIdentifier: Locale.preferredLanguages.first ?? "en-US"
        )
    }

    var prefersSimplifiedChinese: Bool {
        let identifier = preferredLanguageIdentifier.lowercased()
        return identifier.hasPrefix("zh-hans") || identifier.hasPrefix("zh-cn")
    }

    var speechLocaleIdentifier: String {
        prefersSimplifiedChinese ? "zh-CN" : "en-US"
    }

    var responseLanguageInstruction: String {
        prefersSimplifiedChinese
            ? "请只使用简体中文回复。不要因为用户输入中出现英文而切换语言。"
            : "Respond only in English. Do not use Chinese for user-visible prose, plan names, exercise names, notes, reasons, or nutrition notes, even if examples or internal enum values contain Chinese."
    }

    var planContentInstruction: String {
        if prefersSimplifiedChinese {
            return "计划名称、动作名称、备注等用户可见内容使用简体中文；focus 必须使用以下内部枚举值之一：胸部、背部、腿部、肩部、手臂、核心、全身、有氧、休息。"
        }
        return "Write every user-visible JSON string in English, including name, exercises[].name, exercises[].notes, action reasons, summary notes, and meal notes. The focus field is an internal contract and must still be exactly one of these Chinese enum values: 胸部、背部、腿部、肩部、手臂、核心、全身、有氧、休息. Never translate the focus enum, but do translate all visible content."
    }

    var noValueText: String {
        prefersSimplifiedChinese ? "无" : "None"
    }

    var initialPlanSystemPrompt: String {
        if prefersSimplifiedChinese {
            return """
            你是一个专业的健身教练。请根据用户数据生成 JSON 格式的训练计划。

            重要：根据用户情况选择合适的训练分化和循环天数：
            1. 新手/时间少：3-4天循环
            2. 中级/时间适中：4-5天循环
            3. 高级/时间充足：6-7天循环

            JSON 格式要求：
            1. 不要返回任何 Markdown 标记（如 ```json），只返回纯 JSON 字符串
            2. 必须包含：name (计划名称), days (训练日数组)
            3. 每个 day 包含：dayNumber, focus, isRestDay, exercises
            4. 每个 exercise 包含：name, sets, reps, weight, notes
            5. \(planContentInstruction)

            示例 JSON：
            \(workoutPlanJSONExample)
            """
        }
        return """
        You are a professional strength and fitness coach. Generate a training plan as strict JSON.

        Choose an appropriate split and cycle length from the user's profile:
        1. Beginner or limited availability: 3-4 day cycle
        2. Intermediate or moderate availability: 4-5 day cycle
        3. Advanced or high availability: 6-7 day cycle

        JSON requirements:
        1. Return raw JSON only. Do not include Markdown fences or explanatory text.
        2. Required top-level fields: name, days.
        3. Each day must include: dayNumber, focus, isRestDay, exercises.
        4. Each exercise must include: name, sets, reps, weight, notes.
        5. \(planContentInstruction)

        Example JSON:
        \(workoutPlanJSONExample)
        """
    }

    var regeneratePlanSystemPrompt: String {
        if prefersSimplifiedChinese {
            return """
            你是一个专业的健身教练。用户想要修改训练计划的整体结构。请根据用户要求重新生成完整训练计划。

            JSON 格式要求：
            1. 只返回纯 JSON，不要有任何 Markdown 标记（如 ```json）
            2. 不要有任何解释性文字，只返回 JSON
            3. 必须包含：name, days
            4. 每个 day 必须包含：dayNumber, focus, isRestDay, exercises
            5. 休息日必须设置：isRestDay: true, exercises: []
            6. 训练日必须设置：isRestDay: false
            7. \(planContentInstruction)

            示例 JSON：
            \(workoutPlanJSONExample)
            """
        }
        return """
        You are a professional strength and fitness coach. The user wants to change the overall training-plan structure. Regenerate the full plan as strict JSON.

        JSON requirements:
        1. Return raw JSON only. Do not include Markdown fences or explanatory text.
        2. Required top-level fields: name, days.
        3. Each day must include: dayNumber, focus, isRestDay, exercises.
        4. Rest days must use isRestDay: true and exercises: [].
        5. Training days must use isRestDay: false.
        6. \(planContentInstruction)

        Example JSON:
        \(workoutPlanJSONExample)
        """
    }

    var chatSystemIntro: String {
        prefersSimplifiedChinese
            ? "你是一个专业的健身教练 AI 助手。你正在帮助用户管理他们的训练计划。"
            : "You are a professional fitness-coach AI assistant helping the user manage their training plan."
    }

    var dietCoachSystemPrompt: String {
        if prefersSimplifiedChinese {
            return "你是一个专业的营养与饮食顾问。为用户提供饮食建议、营养科普，并可帮助规范化他们的饮食记录。回复应简洁可读。\(responseLanguageInstruction)"
        }
        return "You are a professional nutrition and diet coach. Give practical nutrition advice, explain nutrition simply, and help normalize the user's meal records. Keep replies concise and readable. \(responseLanguageInstruction)"
    }

    var dietImageCoachPrompt: String {
        if prefersSimplifiedChinese {
            return "你是一个专业的营养与饮食顾问。用户会发送食物照片和文字问题，请结合图片和文字给出摄入热量和营养素的估算，以及简洁的饮食建议。\(responseLanguageInstruction)"
        }
        return "You are a professional nutrition and diet coach. The user may send food photos and a text question. Estimate calories and macros from the photos and text, then give concise diet advice. \(responseLanguageInstruction)"
    }

    var dietAnalyzeSystemPrompt: String {
        if prefersSimplifiedChinese {
            return """
            你是一个专业的营养师。请严格按照下述要求解析用户当天饮食：
            1) 仅返回纯 JSON（不包含任何 Markdown 代码块或解释性文字）
            2) 数组 entries 的长度必须与用户输入的条目数完全一致，并与输入顺序一一对应
            3) 每个条目的单位统一为：portion 使用克(g)，calories 使用千卡(kcal)
            4) 每个 entries[i] 必须包含字段：name, portion, unit, calories, protein, carbs, fat, notes, mealType
            5) summary 字段必须包含：totalCalories, protein, carbs, fat, notes
            6) 若用户描述中为“一碗/一盘/一勺”等量词，请合理估算并换算为克(g)
            7) \(responseLanguageInstruction)
            """
        }
        return """
        You are a professional nutritionist. Parse the user's meal records for the current day under these strict rules:
        1) Return raw JSON only. Do not include Markdown fences or explanatory text.
        2) The entries array length must exactly match the number of user input records and preserve the same order.
        3) Use grams (g) for portion and kcal for calories.
        4) Each entries[i] item must include: name, portion, unit, calories, protein, carbs, fat, notes, mealType.
        5) summary must include: totalCalories, protein, carbs, fat, notes.
        6) If the user describes portions such as a bowl, plate, or spoon, estimate reasonably and convert to grams.
        7) Keep food names, notes, and summary notes in English. Keep mealType as the internal value from the user input.
        8) \(responseLanguageInstruction)
        """
    }

    var dietImageAnalyzePrompt: String {
        if prefersSimplifiedChinese {
            return """
            你将看到用户一天内的多条饮食记录。先阅读下面的文字描述，再结合后续的食物照片，输出严格符合下列要求的 JSON：
            1) 仅返回纯 JSON，不包含任何 Markdown 代码块或解释性文字
            2) 数组 entries 的长度必须与用户输入的条目数完全一致，并与输入顺序一一对应
            3) 每个条目的单位统一为：portion 使用克(g)，calories 使用千卡(kcal)
            4) 每个 entries[i] 必须包含字段：name, portion, unit, calories, protein, carbs, fat, notes, mealType
            5) summary 字段必须包含：totalCalories, protein, carbs, fat, notes
            6) 若用户描述中为“一碗/一盘/一勺”等量词，请合理估算并换算为克(g)
            7) \(responseLanguageInstruction)
            8) 对于无法从文字获得的信息，可以参考图片估算食物种类和份量
            """
        }
        return """
        You will see multiple meal records from one day. Read the text records first, then use the food photos to output strict JSON:
        1) Return raw JSON only. Do not include Markdown fences or explanatory text.
        2) The entries array length must exactly match the number of user input records and preserve the same order.
        3) Use grams (g) for portion and kcal for calories.
        4) Each entries[i] item must include: name, portion, unit, calories, protein, carbs, fat, notes, mealType.
        5) summary must include: totalCalories, protein, carbs, fat, notes.
        6) If the user describes portions such as a bowl, plate, or spoon, estimate reasonably and convert to grams.
        7) Use the photos to estimate food type and portion when the text is incomplete.
        8) Keep food names, notes, and summary notes in English. Keep mealType as the internal value from the user input.
        9) \(responseLanguageInstruction)
        """
    }

    var fitnessMediaSystemPrompt: String {
        if prefersSimplifiedChinese {
            return "你是一个专业的私人教练与动作分析专家。用户会上传身材照片或训练视频，并提出与体型或动作相关的问题。请结合视觉信息和文字，给出客观分析和具体可执行的改进建议。\(responseLanguageInstruction)"
        }
        return "You are a professional personal trainer and form-analysis expert. The user may upload body photos or training media and ask questions about physique, technique, or programming. Combine the visual information with the text and give objective, specific, actionable coaching. \(responseLanguageInstruction)"
    }

    var actionJSONExample: String {
        if prefersSimplifiedChinese {
            return """
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
            """
        }
        return """
        {
          "type": "update_plan",
          "actions": [
            {
              "day": 1,
              "old_exercise": "Barbell Squat",
              "new_exercise": "Leg Extension",
              "sets": 4,
              "reps": "12-15",
              "weight": 40,
              "reason": "A knee-friendlier replacement"
            }
          ]
        }
        """
    }

    var workoutPlanJSONExample: String {
        if prefersSimplifiedChinese {
            return """
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
                  "focus": "休息",
                  "isRestDay": true,
                  "exercises": []
                }
              ]
            }
            """
        }
        return """
        {
          "name": "Push Pull Legs Plan",
          "days": [
            {
              "dayNumber": 1,
              "focus": "胸部",
              "isRestDay": false,
              "exercises": [
                {
                  "name": "Barbell Bench Press",
                  "sets": 4,
                  "reps": "8-12",
                  "weight": 60,
                  "notes": "Keep your shoulder blades retracted and controlled"
                }
              ]
            },
            {
              "dayNumber": 2,
              "focus": "休息",
              "isRestDay": true,
              "exercises": []
            }
          ]
        }
        """
    }
}
