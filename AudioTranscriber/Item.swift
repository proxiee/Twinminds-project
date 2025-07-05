//
//  Item.swift
//  AudioTranscriber
//
//  Created by user281756 on 7/2/25.
//

import Foundation

// Simple data model for now - will be enhanced with proper SwiftData when targeting iOS 17+
// this is just a placeholder - not really used anymore
struct Item: Identifiable, Codable {
    let id = UUID()
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
