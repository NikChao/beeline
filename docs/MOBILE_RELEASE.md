# Releasing the apps

How to get Beeline from `ios/` onto the App Store: iPhone and iPad, and the Mac
through Mac Catalyst. One app record in App Store Connect covers all three.

## Before you start: what the app needs from the world

The app is a native shell around the Rails app, so a release is only as good
as the server it points at. Work through these first. App Review will.

1. **A public HTTPS server.** Release builds bake in `BEELINE_URL`. It has to
   be reachable from anywhere (App Review tests from Apple's network), and it
   should be HTTPS. `NSAllowsLocalNetworking` in `ios/Support/Info.plist` only
   relaxes App Transport Security for `.local` names and IP addresses; it does
   nothing for public hosts.
2. **Sign-in.** Beeline has none: anyone who can reach the server can write,
   publish and delete. That's fine at home and not fine in public. Add
   accounts before shipping, and give App Review a demo login in the review
   notes.
3. **Moderation, if pages are public.** Published pages are user-generated
   content, and the App Review Guidelines (section 1.2) then ask for a way to
   filter objectionable content, report it, block abusive users, and contact
   you. If each person's shelf is private, say so in the review notes.
4. **A privacy policy URL**, and an honest App Privacy section in App Store
   Connect (what you collect: the pages people write, at least).
5. **More than a website.** Guideline 4.2 rejects apps that are just a website
   in a frame. Native tabs, the compose button, offline writing and the outbox
   help make the case; mention offline-first writing in the review notes.

## One-time setup

### Apple Developer Program

Enroll at <https://developer.apple.com/programs/> (annual fee). Note your Team
ID from the Membership page.

### Identity and signing

`ios/Config/Local.xcconfig` is gitignored and holds your settings. Copy the
example and fill it in:

```sh
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
```

```
BEELINE_URL = https:/$()/beeline.example.com
BEELINE_BUNDLE_ID = com.yourname.beeline
DEVELOPMENT_TEAM = ABCDE12345
```

(The `$()` keeps xcconfig from reading `//` as a comment.)

Signing is automatic: with a team set, Xcode creates the certificates and
provisioning profiles when you archive.

### App record

In [App Store Connect](https://appstoreconnect.apple.com) ▸ Apps ▸ **+** ▸ New
App: choose iOS (add macOS later from the same record), your bundle ID, a name
and a SKU.

### The icon

`ios/Beeline/Assets.xcassets/AppIcon.appiconset/icon-1024.png` is still the
Rails placeholder. Replace it with a 1024×1024 PNG with no transparency. Xcode
generates every other size from it.

### Export compliance

Beeline only uses HTTPS, which is exempt. Declare it once so App Store Connect
stops asking on every build, by adding this to `ios/Support/Info.plist`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### Privacy manifest

Apple requires a privacy manifest declaring data collection and any
"required reason" APIs. Add `ios/Beeline/PrivacyInfo.xcprivacy` (Xcode ▸ File ▸
New ▸ File ▸ App Privacy). The app's own code uses none of the required-reason
APIs today; Hotwire Native ships its own manifest. Declare the content people
write as collected data, linked to them once accounts exist.

## Each release

### 1. Bump the version

In `ios/Beeline.xcodeproj` (target Beeline ▸ General), or the build settings:

- `MARKETING_VERSION`: what people see, e.g. `1.1`.
- `CURRENT_PROJECT_VERSION`: the build number. Must go up with every upload,
  even for the same version.

### 2. Deploy the server first

Any server change the app relies on (routes, the path configuration at
`/configurations/ios_v1.json`, layout tweaks for `hotwire_native_app?`) must be
live before the build reaches people. Most changes need no app release at all:
the app renders whatever the server sends.

### 3. Run the tests

```sh
bin/rails test && bin/rails test:system
```

The offline UI test drives the app in the simulator in three steps: server
up, server down, server up again. Point a build at a local server and run each
step, stopping and starting the server between them:

```sh
for step in test1_keepPagesWhileOnline test2_writeWithoutTheServer test3_syncWhenTheServerIsBack; do
  read -p "Server ready for $step? "
  xcodebuild test -project ios/Beeline.xcodeproj -scheme Beeline \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    BEELINE_URL=http://localhost:3000 \
    -only-testing:BeelineUITests/OfflineUITests/$step
done
```

### 4. Archive and upload

**From Xcode:** pick *Any iOS Device (arm64)* as the destination, then
Product ▸ Archive. In the Organizer: Distribute App ▸ App Store Connect ▸
Upload.

**From the command line:**

```sh
xcodebuild -project ios/Beeline.xcodeproj -scheme Beeline \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Beeline.xcarchive archive

xcodebuild -exportArchive -archivePath build/Beeline.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

with an `ExportOptions.plist` that uploads straight to App Store Connect:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>ABCDE12345</string>
</dict>
</plist>
```

`build/` is gitignored. Uploads take a few minutes to process before they
appear in App Store Connect.

### 5. TestFlight

Every processed build is available in TestFlight. Add yourself as an internal
tester and try it on a real device, against the real server:

- Write a page, publish it, mark up a draft.
- Turn on Airplane Mode: write and publish a page, check it appears on the
  shelf as waiting, then turn Airplane Mode off and watch it sync.
- On iPad: draw with a finger and with Apple Pencil.

External testers (people outside your team) need a short Beta App Review the
first time.

### 6. Submit for review

In App Store Connect, on the version:

- **Screenshots.** The largest sizes are enough; smaller ones are derived:
  6.9" iPhone (1320×2868) and 13" iPad (2064×2752). The iPhone 17 Pro Max and
  iPad Pro 13-inch simulators produce these: `xcrun simctl io booted screenshot shot.png`.
- **Description, keywords, support URL, privacy policy URL.**
- **Review notes:** a demo login, the server being public, and how offline
  writing works.
- Pick the build, then Add for Review ▸ Submit.

Review usually takes a day or two. Choose manual release if the server needs
to change in step with the app.

## The Mac app

The target supports Mac Catalyst (`SUPPORTS_MACCATALYST = YES`), so the same
project builds a native Mac app.

1. **Sandbox.** Mac App Store apps must be sandboxed. Add a
   `Beeline.entitlements` with the App Sandbox and outgoing connections:

   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   ```

   and set `CODE_SIGN_ENTITLEMENTS = Beeline.entitlements` for the target.
2. **Archive** with the *My Mac (Mac Catalyst)* destination, or
   `-destination 'generic/platform=macOS,variant=Mac Catalyst'`, and upload the
   same way.
3. In App Store Connect, add the **macOS** platform to the app record, with
   Mac screenshots (e.g. 2880×1800).

The simplest alternative is to skip Catalyst and let the iPad app run on Apple
silicon Macs as-is ("Designed for iPad"). Leave it enabled under Pricing and
Availability.

## After release

- Server changes ship without an app update, but keep older app versions
  working: path configuration rules and `hotwire_native_app?` layouts are read
  by every installed version.
- Bump `VERSION` in `app/views/pwa/service-worker.js` when browser offline
  caching changes, and the path configuration if navigation rules change.
- Crash reports and metrics are in Xcode ▸ Organizer and App Store Connect.
