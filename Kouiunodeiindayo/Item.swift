//
//  Item.swift
//  Kouiunodeiindayo
//
//  Created by 航世 on 2026/09/21.
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
