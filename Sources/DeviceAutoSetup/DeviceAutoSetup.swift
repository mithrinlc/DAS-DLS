// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import Foundation


public class DeviceAutoSetup {
    static let backendURL = "ENDPOINT"
    static let jwtKey = ""
    static let retryInterval = TimeInterval(60) // 60 seconds
    static var retryTimer: Timer?
    
    public static func setup(completion: @escaping (Bool) -> Void) {
        print("DeviceAutoSetup: Starting setup process.")
        if isFirstLaunch() {
            print("DeviceAutoSetup: First launch detected.")
            performFirstTimeSetup(completion: completion)
        } else {
            print("DeviceAutoSetup: Not first launch, proceeding with regular setup.")
            regularSetup(completion: completion)
        }
    }
    
    private static func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        print("DeviceAutoSetup: Checking if first launch - \(hasLaunchedBefore ? "No" : "Yes")")
        return !hasLaunchedBefore
    }
    
    private static func performFirstTimeSetup(completion: @escaping (Bool) -> Void) {
        print("DeviceAutoSetup: Performing first-time setup.")
        let deviceInfo = DeviceProfile.current()
        let encryptedSeed = encryptSeed(with: deviceInfo.vendorID)
        print("DeviceAutoSetup: Encrypted seed generated.")
        sendSeedToBackend(encryptedSeed, deviceInfo: deviceInfo, completion: completion)
        UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        print("DeviceAutoSetup: First-time setup flag updated in UserDefaults.")
    }
    
    private static func regularSetup(completion: @escaping (Bool) -> Void) {
        print("DeviceAutoSetup: Performing regular setup.")
        let deviceInfo = DeviceProfile.current()
        requestConfigForDevice(deviceInfo: deviceInfo, completion: completion)
    }
    
    private static func encryptSeed(with vendorID: String) -> String {
        print("DeviceAutoSetup: Encrypting seed with vendorID.")
        return "Encrypted(\(vendorID))"
    }
    
    private static func sendSeedToBackend(_ encryptedSeed: String, deviceInfo: DeviceProfile, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(backendURL)/register") else {
            print("DeviceAutoSetup: Invalid URL for backend.")
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "encryptedSeed": encryptedSeed,
            "deviceInfo": [
                "modelIdentifier": deviceInfo.model,
                "iOSVersion": deviceInfo.osVersion
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("DeviceAutoSetup: Sending seed to backend.")
        
        print("DeviceAutoSetup: Prepared request with body: \(body)")
        
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DeviceAutoSetup: Error sending request to backend - \(error.localizedDescription)")
                startRetryMechanism(with: encryptedSeed, deviceInfo: deviceInfo)
                completion(false)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DeviceAutoSetup: No valid HTTP response received.")
                completion(false)
                return
            }
            if httpResponse.statusCode == 200, let data = data {
                print("DeviceAutoSetup: Received successful response from server.")
                handleSuccessfulResponse(data, completion: completion)
            } else {
                print("DeviceAutoSetup: Server returned an error or network issue. Starting retry mechanism.")
                startRetryMechanism(with: encryptedSeed, deviceInfo: deviceInfo)
                completion(false)
            }
        }.resume()
    }
    
    private static func handleSuccessfulResponse(_ data: Data, completion: (Bool) -> Void) {
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               
                let jwt = jsonResponse["jwt"] as? String {
                print("DeviceAutoSetup: JSON Response: \(jsonResponse)")
                
                print("DeviceAutoSetup: JWT received and being saved to Keychain.")
                if let jwtData = jwt.data(using: .utf8) {
                    KeychainManager.save(key: jwtKey, data: jwtData)
                }
                completion(true)
            } else {
                print("DeviceAutoSetup: No JWT found in response.")
                completion(false)
            }
        } catch {
            print("DeviceAutoSetup: Error parsing JSON response - \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private static func startRetryMechanism(with encryptedSeed: String, deviceInfo: DeviceProfile) {
        print("DeviceAutoSetup: Starting retry mechanism.")
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: true) { _ in
            print("DeviceAutoSetup: Attempting to reconnect to the backend...")
            sendSeedToBackend(encryptedSeed, deviceInfo: deviceInfo, completion: { _ in })
        }
    }
    
    private static func requestConfigForDevice(deviceInfo: DeviceProfile, completion: @escaping (Bool) -> Void) {
        guard let jwtData = KeychainManager.load(key: jwtKey),
              let jwt = String(data: jwtData, encoding: .utf8) else {
            print("DeviceAutoSetup: JWT not found in Keychain.")
            completion(false)
            return
        }

        guard let url = URL(string: "\(backendURL)/requestConfig") else {
            print("DeviceAutoSetup: Invalid URL for backend.")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "modelIdentifier": deviceInfo.model,
            "iOSVersion": deviceInfo.osVersion
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DeviceAutoSetup: Error sending request to backend - \(error.localizedDescription)")
                completion(false)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DeviceAutoSetup: No valid HTTP response received.")
                completion(false)
                return
            }
            if httpResponse.statusCode == 200, let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("DeviceAutoSetup: JSON Response: \(jsonResponse)")
                        completion(true)
                    } else {
                        print("DeviceAutoSetup: Invalid JSON response.")
                        completion(false)
                    }
                } catch {
                    print("DeviceAutoSetup: Error parsing JSON response - \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                print("DeviceAutoSetup: Server returned an error - Status Code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("DeviceAutoSetup: Server Response: \(responseString)")
                }
                completion(false)
            }
        }.resume()
    }
}
