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
- For subscriptions: digital subscriptions sold inside the app must use Apple IAP. The native iOS app hides Stripe checkout and uses Apple In-App Purchase via RevenueCat (see below). Web users still subscribe through Stripe.

## Apple In-App Purchase (RevenueCat)

The iOS app must not offer Stripe for digital subscriptions (App Store rule 3.1.1). The hosted web app detects the Capacitor shell and swaps Stripe for Apple IAP automatically once this plugin is installed:

```bash
npm install @revenuecat/purchases-capacitor@^9   # already in package.json
npx cap sync ios
```

### One-time setup (before App Store submission)

1. **App Store Connect** — create an auto-renewable subscription (e.g. `reefly_premium_monthly`, $3.99/month) under your app.
2. **RevenueCat** ([revenuecat.com](https://www.revenuecat.com)) — create a project, add the iOS app, import the App Store product, and create an entitlement named `premium` linked to that product. Add a default offering with one monthly package.
3. **RevenueCat webhook** — point it at `https://reeflycare.com/api/revenuecat/webhook` with an Authorization header matching `REVENUECAT_WEBHOOK_AUTH_HEADER` in the web app's env.
4. **Web app env** (Vercel / `.env.local` on the Reefly repo) — set:
   - `NEXT_PUBLIC_REVENUECAT_IOS_API_KEY` (public iOS key)
   - `NEXT_PUBLIC_REVENUECAT_ENTITLEMENT_ID=premium`
   - `REVENUECAT_SECRET_API_KEY` (secret REST key)
   - `REVENUECAT_WEBHOOK_AUTH_HEADER=Bearer <your-secret>`
5. **Supabase migration** — apply `073_consumer_subscriptions_apple_iap.sql` on the Reefly database.
6. **Deploy the web app** — the iOS shell loads `https://reeflycare.com`, so the native-detection and Apple IAP UI must be live on the site before testing in the app.

RevenueCat's app user id is set to the Supabase user id at login, so purchases map to the correct account and Premium unlocks through the existing `consumer_subscriptions` table.

## Bundle identifier

`com.reeflycare.app` (change in both `capacitor.config.ts` and the Xcode project if you need a different one).
