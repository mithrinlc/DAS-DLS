import Foundation
import UIKit

public struct Settings: Codable {
    public var hotkey1Prompt: String
    public var hotkey2Prompt: String
    public var temperature: Double
    public var themeID: String
    public var imageSize: String
    public var buttonLayout: String
    public var buttonRoundness: Double

    public init(hotkey1Prompt: String, hotkey2Prompt: String, temperature: Double, themeID: String, imageSize: String, buttonLayout: String, buttonRoundness: Double) {
        self.hotkey1Prompt = hotkey1Prompt
        self.hotkey2Prompt = hotkey2Prompt
        self.temperature = temperature
        self.themeID = themeID
        self.imageSize = imageSize
        self.buttonLayout = buttonLayout
        self.buttonRoundness = buttonRoundness
    }
}

public struct TooltipInfo: Identifiable {
    public var id: String
    public var message: String

    public init(id: String, message: String) {
        self.id = id
        self.message = message
    }
}

public struct DeviceConfiguration: Codable {
    var modelIdentifier: String
    var iOSVersion: String
    var designAdjustments: DesignAdjustments

    struct DesignAdjustments: Codable {
        var buttonPadding: CGFloat
        var fontSize: CGFloat
        // Add more design-related properties as needed
    }
}

public class ConfigurationDatabase {
    private var configurations: [DeviceConfiguration]
    private var defaultConfiguration: DeviceConfiguration

    init(configurations: [DeviceConfiguration], defaultConfiguration: DeviceConfiguration) {
        self.configurations = configurations
        self.defaultConfiguration = defaultConfiguration
    }

    func configuration(for modelIdentifier: String, iOSVersion: String) -> DeviceConfiguration {
        return configurations.first { $0.modelIdentifier == modelIdentifier && $0.iOSVersion == iOSVersion } ?? defaultConfiguration
    }

    func addConfiguration(_ config: DeviceConfiguration) {
        configurations.append(config)
    }
}
