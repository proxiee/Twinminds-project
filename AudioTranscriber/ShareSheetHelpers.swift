#if os(iOS)
import UIKit
import SwiftUI

// helper for sharing files and text
public struct ShareSheetItem: Identifiable {
    public let id = UUID()
    public let items: [Any]
    public init(items: [Any]) {
        self.items = items
    }
}

// wrapper for iOS share sheet
public struct ActivityViewController: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif 