//
//  Item.swift
//  AudioTranscriber
//
//  Created by user281756 on 7/2/25.
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
