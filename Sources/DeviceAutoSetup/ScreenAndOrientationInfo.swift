import Foundation
import UIKit

class ScreenAndOrientationInfo {
    static var currentOrientation: UIInterfaceOrientation {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .unknown
        } else {
            return UIApplication.shared.statusBarOrientation
        }
    }

    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }

    static var screenScale: CGFloat {
        return UIScreen.main.scale
    }

    static func currentInfo() -> (orientation: UIInterfaceOrientation, screenSize: CGSize, screenScale: CGFloat) {
        return (currentOrientation, screenSize, screenScale)
    }
}
