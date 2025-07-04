import Foundation
import Network
import SwiftUI

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        
        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "network"
            case .unknown: return "network.slash"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Network Status View
struct NetworkStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: networkMonitor.isConnected ? networkMonitor.connectionType.icon : "network.slash")
                .font(.caption)
                .foregroundColor(networkMonitor.isConnected ? .green : .red)
            
            Text(networkMonitor.isConnected ? networkMonitor.connectionType.displayName : "Offline")
                .font(.caption)
                .foregroundColor(networkMonitor.isConnected ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(networkMonitor.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
}

// MARK: - Network Status Badge
struct NetworkStatusBadge: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(networkMonitor.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            
            Text(networkMonitor.isConnected ? "Online" : "Offline")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
} 