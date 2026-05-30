# Reefly iOS

Capacitor wrapper that ships the hosted Reefly web app (`https://reeflycare.com`) as a native iOS app for the App Store.

This repo intentionally contains no product code — the UI lives in the main Reefly web app. This project only builds the native shell, the splash screen, and any native plugins (camera, push, etc.) we add later.

## Prerequisites

- macOS with Xcode 15+
- Node 18+ and npm
- CocoaPods (`sudo gem install cocoapods` or `brew install cocoapods`)
- An Apple Developer account for device builds / App Store submission

Verify:

```bash
xcodebuild -version
pod --version
node -v
```

## First-time setup

```bash
npm install
npm install @capacitor/core @capacitor/cli @capacitor/ios @capacitor/app @capacitor/status-bar @capacitor/splash-screen
npx cap add ios
npx cap sync ios
```

`npx cap add ios` generates the `ios/` Xcode project from `capacitor.config.ts`. `cap sync` copies `www/` and installs CocoaPods.

## Run in the simulator

```bash
npm run open      # opens Xcode — pick a simulator, hit ▶
# or
npm run run       # launches via the Capacitor CLI
```

## What this app does

`capacitor.config.ts` sets `server.url = https://reeflycare.com`, so the WebView loads the live site directly. The `www/` folder is only an offline fallback page.

## Updating the app

The web app updates automatically — users get the latest UI whenever the site is deployed. You only need to ship a new build of this iOS app when:

- You change `capacitor.config.ts`
- You add or update a native plugin
- You change app icons, splash screen, Info.plist, signing, or version
- You need to satisfy App Store review

## Versioning a release

Bump the version in Xcode (`Reefly` target → General → Identity → Version / Build), then:

```bash
npx cap sync ios
npx cap open ios
# Product → Archive → Distribute App → App Store Connect
```

## App Store notes

Apple may reject pure-WebView apps. To reduce risk:

- Add at least one native capability (push, camera, share). The `@capacitor/app`, `@capacitor/status-bar`, and `@capacitor/splash-screen` plugins are already wired in.
- Provide a clear value proposition in the listing.
- Make sure the site renders well at iPhone sizes and respects safe-area insets.
- For subscriptions: digital subscriptions sold inside the app must use Apple IAP. The current setup uses Stripe on the web — keep paid signup gated to the web flow, or migrate to RevenueCat/Apple IAP later.

## Bundle identifier

`com.reeflycare.app` (change in both `capacitor.config.ts` and the Xcode project if you need a different one).
