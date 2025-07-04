#if os(iOS)
import UIKit
import SwiftUI

public struct ShareSheetItem: Identifiable {
    public let id = UUID()
    public let items: [Any]
    public init(items: [Any]) {
        self.items = items
    }
}

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