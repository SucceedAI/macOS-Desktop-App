import Foundation
import IOKit

// static utility class
final class SystemUtility {
    static func getOperatingSystemInfo() -> [String: String] {
        var info = [String: String]()

        let osVersion = getOSVersion()
        info["osVersion"] = osVersion

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osName = getOSName(version: version)
        info["osName"] = osName

        if let model = getMacModel() {
            info["model"] = model
        }

        return info
    }
    
    static func getOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        return versionString
    }

    static func getOSName(version: OperatingSystemVersion) -> String {
        // You can map more versions here
        switch (version.majorVersion, version.minorVersion) {
            case (10, 15):
                return "macOS Catalina"
            case (11, _):
                return "macOS Big Sur"
            case (12, _):
                return "macOS Monterey"
            default:
                return "macOS (Unknown Version)"
        }
    }
    
    static func getMacModel() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if service == 0 {
            return nil
        }

        defer { IOObjectRelease(service) }

        guard let modelIdentifier = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data else {
                return nil
        }

        return String(data: modelIdentifier, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }
}
