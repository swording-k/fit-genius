//
//  Item.swift
//  FitGenius
//
//  Created by 宝剑 on 2025/11/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
