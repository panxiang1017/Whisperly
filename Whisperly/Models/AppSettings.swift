import Foundation
import SwiftData

@Model
final class AppSettings {
    var iCloudSyncEnabled: Bool = false
    var preferredLanguage: String?
    var summaryStyle: String = "concise"

    init(
        iCloudSyncEnabled: Bool = false,
        preferredLanguage: String? = nil,
        summaryStyle: String = "concise"
    ) {
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.preferredLanguage = preferredLanguage
        self.summaryStyle = summaryStyle
    }
}
