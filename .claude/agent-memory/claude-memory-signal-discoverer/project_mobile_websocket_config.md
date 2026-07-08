---
name: Mobile WebSocket network permissions
description: Required Android and iOS configuration for WebSocket connections, including localhost dev setup
type: project
---

**Android (`client/android/app/src/main/AndroidManifest.xml`):**
Two entries required for WebSocket to work:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
And inside `<application>`:
```xml
android:usesCleartextTraffic="true"
```
The cleartext flag is needed for plain `ws://` connections (non-TLS) to the local dev server.

**iOS (`client/ios/Runner/Info.plist`):**
For connecting to localhost during development, add this key under `NSAppTransportSecurity` — do NOT disable ATS globally:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```
`NSAllowsLocalNetworking: true` allows `ws://localhost` without requiring `NSAllowsArbitraryLoads: true` (which Apple rejects in App Store submissions).

**Why:** Both are required for the Flutter client to connect to the Dart WebSocket server during development. Discovered during platform config commit.

**How to apply:** Any time the client is rebuilt fresh or a new device target is added, verify these settings are present before testing connectivity.
