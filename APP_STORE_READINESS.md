# App Store Readiness Checklist

## ✅ Completed: Code Changes

### 1. Keystroke Injection Removal from `main`
- Deleted `GlobalKeyMonitor.swift` entirely
- Stripped all keystroke injection properties from `ProximityMonitor`
- Removed keystroke injection UI from `SettingsView`
- Removed `injectPassword()` method and protocol declaration
- Updated test mocks
- **Status**: Mac app builds cleanly, zero keystroke references remain
- **Preservation**: Full code preserved on `feature/keystroke-injection` branch (commit: 3eb07ba)

### 2. iOS App Store Technical Blockers
- ✅ Added `ITSAppUsesNonExemptEncryption = false` to `ProximityUnlockiOS-Info.plist`
  - Rationale: Uses only standard Apple crypto APIs (CryptoKit, MPC TLS), no custom encryption
- ✅ Created `PrivacyInfo.xcprivacy` with required API declarations
  - `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1: storing app settings)
  - No file timestamp access, no disk space probing
- ✅ Removed empty `com.apple.developer.associated-domains` from entitlements
  - Was causing code signing failures; not used by this app

---

## 📋 Remaining: Manual Steps (User Action Required)

These **cannot** be automated and require user interaction:

### 1. Privacy Policy URL
**Required**: App Store submission will block without this.
- **Where to host**: Any HTTPS URL (GitHub Pages, personal website, etc.)
- **Minimum content**: "This app uses Bluetooth for proximity detection and local network for peer-to-peer commands. No data leaves your local network. [Technical details...]"
- **Must be live** before submission (App Store validates the URL)

### 2. App Store Connect Metadata
Login to [App Store Connect](https://appstoreconnect.apple.com) and fill out:
- **App Name**: ProximityUnlock (or chosen name)
- **Subtitle**: ≤30 characters, e.g., "Proximity-Based Mac Unlock"
- **Description**: ~300 words explaining:
  - What the app does
  - How to pair with the Mac app
  - Permissions required (Bluetooth, Face ID)
  - Privacy statement
- **Keywords**: ≤100 characters, e.g., "security, unlock, mac, proximity, biometric"
- **Support URL**: Point to your privacy policy or support page
- **Category**: Utilities or Productivity
- **Age Rating**: Select "4+" (no objectionable content)

### 3. Screenshots (Required)
- **Minimum**: iPhone 6.9" screenshots (required for 2024+ submissions)
- **Content**: Capture these screens:
  1. Pairing setup screen
  2. Main status/connection screen
  3. Proximity status display
  4. Confirmation dialog (iPhone approving Mac unlock)
- **Format**: Portrait orientation, dimensions per App Store guidelines

### 4. Review Notes
In App Store Connect, add notes explaining:
```
This app requires a paired Mac running the companion app (ProximityUnlockMac).
- BLE is used for proximity detection (RSSI signal strength)
- MultipeerConnectivity provides secure command relay over local peer-to-peer WiFi
- Face ID validates the unlock request on iPhone before sending approval
- All data remains on the local network; no external servers involved
```

### 5. Distribution Certificate & Signing
- In Xcode → Signing & Capabilities, sign in with Apple ID `39VK47BC8L`
- Ensure a valid **Distribution Certificate** exists (not Development)
- If missing, create one in [Apple Developer portal](https://developer.apple.com/account/resources/certificates/list)
- `CODE_SIGN_STYLE = Automatic` will handle the rest

---

## 🚀 Next Steps

1. **Create privacy policy** (host on GitHub Pages or personal domain)
2. **Log into App Store Connect** and create a new app listing
3. **Fill metadata** and upload screenshots
4. **Set up signing**: Ensure distribution certificate is active
5. **Archive & validate** in Xcode:
   ```
   xcodebuild -scheme ProximityUnlockiOS -configuration Release archive
   ```
6. **Submit** via App Store Connect
7. **Wait** for review (typically 24-48 hours)

---

## ⚠️ Important Notes

- **Deployment Target**: Currently set to iOS 18.6 (very restrictive). Consider lowering to iOS 16 or 17 to reach more devices.
- **Export Compliance**: This app uses encryption (AES-GCM, ECDSA via CryptoKit). The `ITSAppUsesNonExemptEncryption = false` declaration assumes you're using standard Apple APIs only — verify this is correct for your implementation.
- **Pairing Security**: The app uses ECDH key exchange and ECDSA signing for pairing. This is correctly disclosed as exempt encryption (standard algorithms).

---

## Files Modified in This Session

| File | Change |
|------|--------|
| `ProximityUnlockMac/GlobalKeyMonitor.swift` | Deleted |
| `ProximityUnlockMac/ProximityMonitor.swift` | Removed injection properties & methods |
| `ProximityUnlockMac/SettingsView.swift` | Removed injection UI section |
| `ProximityUnlockMac/UnlockManager.swift` | Removed `injectPassword()` |
| `ProximityUnlockMac/BLEProtocols.swift` | Removed `injectPassword()` from protocol |
| `ProximityUnlockMacTests/Mocks/MockUnlockManager.swift` | Updated mock |
| `ProximityUnlockiOS-Info.plist` | Added `ITSAppUsesNonExemptEncryption` |
| `ProximityUnlockiOS/PrivacyInfo.xcprivacy` | Created (required for all 2024+ submissions) |
| `ProximityUnlockiOS/ProximityUnlockiOS.entitlements` | Removed empty `associated-domains` |

---

## Testing Before Submission

```bash
# Verify Mac app builds cleanly (no keystroke references)
xcodebuild -scheme ProximityUnlockMac -configuration Debug build

# Archive iOS app for submission
xcodebuild -scheme ProximityUnlockiOS -configuration Release archive

# Validate in Xcode Organizer before uploading
# (Organizer → Archives → Validate App)
```

App is now ready for App Store submission once manual steps above are completed. 🎉
