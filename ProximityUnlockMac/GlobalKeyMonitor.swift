import CoreGraphics
import Foundation
import os

/// Listens for a user-defined key sequence typed within a short time window.
/// Uses a listen-only CGEventTap — events are never swallowed or modified.
///
/// Requires Input Monitoring permission (System Settings > Privacy & Security > Input Monitoring).
/// If permission is denied, `start()` is a no-op and logs a warning.
class GlobalKeyMonitor {

    // MARK: - Public

    var onTriggered: (() -> Void)?

    private(set) var isRunning: Bool = false

    /// The sequence of characters to detect (e.g., "wasd"). Case-sensitive.
    var triggerSequence: String = "wasd" {
        didSet { clearBuffer() }
    }

    /// All keystrokes must be typed within this window (seconds) to count as the trigger.
    var triggerWindowSeconds: TimeInterval = 0.5

    static var hasInputMonitoringPermission: Bool {
        CGPreflightListenEventAccess()
    }

    static func requestInputMonitoringPermission() {
        CGRequestListenEventAccess()
    }

    // MARK: - Private

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: [(char: Character, time: Date)] = []

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard !triggerSequence.isEmpty else { return }
        guard Self.hasInputMonitoringPermission else {
            Log.unlock.warning("GlobalKeyMonitor: Input Monitoring permission not granted")
            return
        }

        // Use an unretained pointer — stop() is called in deinit before self is freed.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            Log.unlock.error("GlobalKeyMonitor: failed to create CGEvent tap (check Input Monitoring)")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        Log.unlock.info("GlobalKeyMonitor started — trigger: '\(self.triggerSequence, privacy: .public)', window: \(self.triggerWindowSeconds, privacy: .public)s")
    }

    func stop() {
        guard isRunning else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
        clearBuffer()
        Log.unlock.info("GlobalKeyMonitor stopped")
    }

    deinit { stop() }

    // MARK: - Event Handling

    private func handleEvent(_ event: CGEvent) {
        // Extract the typed character(s) from the event.
        var actualLength = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &actualLength, unicodeString: nil)
        guard actualLength > 0 else { return }

        var chars = [UniChar](repeating: 0, count: actualLength)
        event.keyboardGetUnicodeString(maxStringLength: actualLength, actualStringLength: &actualLength, unicodeString: &chars)
        let string = String(utf16CodeUnits: chars, count: actualLength)
        guard let char = string.first else { return }

        let now = Date()
        buffer.append((char: char, time: now))

        // Drop entries that fall outside the time window.
        buffer = buffer.filter { now.timeIntervalSince($0.time) <= triggerWindowSeconds }

        // Fire if the buffer ends with the trigger sequence.
        let bufferedStr = String(buffer.map(\.char))
        if bufferedStr.hasSuffix(triggerSequence) {
            clearBuffer()
            Log.unlock.info("GlobalKeyMonitor: trigger sequence matched")
            onTriggered?()
        }
    }

    private func clearBuffer() {
        buffer.removeAll()
    }
}
