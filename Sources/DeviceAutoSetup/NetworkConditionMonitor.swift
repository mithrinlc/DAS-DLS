import Network
import Foundation

class NetworkConditionMonitor {
    static let shared = NetworkConditionMonitor()
    private var monitor: NWPathMonitor?
    private var isMonitoring = false

    var currentStatus: NWPath.Status = .requiresConnection

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }

        monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.currentStatus = path.status
        }
        monitor?.start(queue: queue)
        isMonitoring = true
    }

    private func stopMonitoring() {
        guard isMonitoring, let monitor = monitor else { return }
        monitor.cancel()
        self.monitor = nil
        isMonitoring = false
    }

    static func currentNetworkStatus() -> NWPath.Status {
            return NetworkConditionMonitor.shared.currentStatus
    }
}
