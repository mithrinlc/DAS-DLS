import Foundation
import UIKit

struct DeviceProfile {
    let model: String
    let osVersion: String
    let deviceType: DeviceType
    let vendorID: String

    enum DeviceType {
        case iPhone
        case iPad
        case unknown
    }

    static func current() -> DeviceProfile {
        return DeviceProfile(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            deviceType: currentDeviceType(),
            vendorID: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        )
    }
    
    private static func currentDeviceType() -> DeviceType {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return .iPhone
        case .pad: return .iPad
        default: return .unknown
        }
    }
}
