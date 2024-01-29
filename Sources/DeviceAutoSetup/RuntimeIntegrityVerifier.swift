import UIKit
import MachO.dyld

class RuntimeIntegrityVerifier {
    static func verifyIntegrity() -> Bool {
        return verifyRuntimeEnvironment() && checkDynamicLinkerIntegrity() && checkFileSystemIntegrity()
    }

    private static func verifyRuntimeEnvironment() -> Bool {
        return !isDebuggerAttached() && !isRunningOnSimulator()
    }

    private static func isDebuggerAttached() -> Bool {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let sysctlResult = sysctl(&mib, UInt32(mib.count), &kinfo, &size, nil, 0)
        return sysctlResult == 0 && (kinfo.kp_proc.p_flag & P_TRACED) != 0
    }

    private static func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func checkDynamicLinkerIntegrity() -> Bool {
        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                if name.contains("some_unexpected_library") {
                    return false
                }
            }
        }
        return true
    }

    private static func checkFileSystemIntegrity() -> Bool {
        let fileManager = FileManager.default
        let pathsToCheck = ["/Applications/Cydia.app", "/bin/bash", "/usr/sbin/sshd", "/Library/MobileSubstrate", "/usr/sbin/frida-server", "/etc/apt"]
        return !pathsToCheck.contains(where: fileManager.fileExists(atPath:))
    }
}
