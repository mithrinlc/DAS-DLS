import UIKit
import CoreMotion
import SystemConfiguration.CaptiveNetwork
import CoreTelephony
import Metal
import LocalAuthentication

struct DeviceCapabilities {
    static func supportsAdvancedGraphics() -> Bool {
        let device = MTLCreateSystemDefaultDevice()
        return device?.supportsFeatureSet(.iOS_GPUFamily4_v1) ?? false
    }

    static func hasMotionCapabilities() -> Bool {
        return CMMotionActivityManager.isActivityAvailable()
    }

    static func hasBiometricAuthentication() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return .faceID
            case .touchID:
                return .touchID
            default:
                return .none
            }
        }
        return .none
    }

    static func networkType() -> NetworkType {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com")
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)

        if flags.contains(.reachable) {
            if flags.contains(.isWWAN) {
                let networkInfo = CTTelephonyNetworkInfo()
                let carrierType = networkInfo.serviceCurrentRadioAccessTechnology
                return carrierType?.values.first.map { NetworkType(cellularType: $0) } ?? .unknown
            } else {
                return .wifi
            }
        }
        return .none
    }

    static func batteryHealth() -> BatteryHealth {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        switch batteryLevel {
        case 0...0.2:
            return .critical
        case 0.2...0.5:
            return .low
        case 0.5...0.8:
            return .medium
        case 0.8...1.0:
            return .high
        default:
            return .unknown
        }
    }

    static func availableStorageSpace() -> StorageSpace {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSize = attributes[.systemFreeSize] as? Int64 ?? 0
            return .init(freeBytes: freeSize)
        } catch {
            return StorageSpace(freeBytes: -1)
        }
    }

    enum BiometricType {
        case faceID, touchID, none
    }

    enum NetworkType {
        case wifi, cellular2G, cellular3G, cellular4G, cellular5G, none, unknown

        init(cellularType: String) {
            switch cellularType {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
                self = .cellular2G
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA:
                self = .cellular3G
            case CTRadioAccessTechnologyLTE:
                self = .cellular4G
            default:
                if #available(iOS 14.1, *), cellularType == CTRadioAccessTechnologyNRNSA || cellularType == CTRadioAccessTechnologyNR {
                    self = .cellular5G
                } else {
                    self = .unknown
                }
            }
        }
    }

    enum BatteryHealth {
        case high, medium, low, critical, unknown
    }

    struct StorageSpace {
        let freeBytes: Int64

        var formatted: String {
            ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
        }
    }
}
