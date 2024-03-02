//
//  Item.swift
//  Succeed AI
//
//  Created by Pierre on 3/3/2024.
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
