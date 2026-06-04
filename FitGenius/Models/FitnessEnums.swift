import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case loseWeight = "减重"
    case buildMuscle = "增肌"
    case improveEndurance = "提升耐力"
    case flexibility = "柔韧性"
    case generalHealth = "一般健康"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .loseWeight: return "fitness_goal_lose_weight".localized
        case .buildMuscle: return "fitness_goal_build_muscle".localized
        case .improveEndurance: return "fitness_goal_endurance".localized
        case .flexibility: return "fitness_goal_flexibility".localized
        case .generalHealth: return "fitness_goal_general_health".localized
        }
    }
}

enum WorkoutEnvironment: String, Codable, CaseIterable, Identifiable {
    case gym = "健身房"
    case home = "家庭"
    case outdoor = "户外"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .gym: return "workout_environment_gym".localized
        case .home: return "workout_environment_home".localized
        case .outdoor: return "workout_environment_outdoor".localized
        }
    }
}

enum BodyPartFocus: String, Codable, CaseIterable, Identifiable {
    case chest = "胸部"
    case back = "背部"
    case legs = "腿部"
    case shoulders = "肩部"
    case arms = "手臂"
    case core = "核心"
    case fullBody = "全身"
    case cardio = "有氧"
    case rest = "休息"  // 休息日
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .chest: return "body_focus_chest".localized
        case .back: return "body_focus_back".localized
        case .legs: return "body_focus_legs".localized
        case .shoulders: return "body_focus_shoulders".localized
        case .arms: return "body_focus_arms".localized
        case .core: return "body_focus_core".localized
        case .fullBody: return "body_focus_full_body".localized
        case .cardio: return "body_focus_cardio".localized
        case .rest: return "body_focus_rest".localized
        }
    }
}
