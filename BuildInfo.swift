import Foundation

/// Human-readable build identifier shown in Settings / More (which binary is running).
enum BuildInfo {
    /// Last modification time of the app executable (updates on each build/install). Shown in local timezone.
    static var stamp: String {
        guard let exeURL = Bundle.main.executableURL else { return "—" }
        let path = exeURL.resolvingSymlinksInPath().path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
