import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case loseWeight = "减重"
    case buildMuscle = "增肌"
    case improveEndurance = "提升耐力"
    case flexibility = "柔韧性"
    case generalHealth = "一般健康"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        self.rawValue
    }
}

enum WorkoutEnvironment: String, Codable, CaseIterable, Identifiable {
    case gym = "健身房"
    case home = "家庭"
    case outdoor = "户外"
    
    var id: String { self.rawValue }
    
    var localizedName: String {
        self.rawValue
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
        self.rawValue
    }
}
