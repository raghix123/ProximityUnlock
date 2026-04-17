import Foundation
import os
import ServiceManagement

@MainActor
enum LoginItemManager {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                Log.ui.info("Launch at login set to \(newValue, privacy: .public)")
            } catch {
                Log.ui.error("Launch at login toggle failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
