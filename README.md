# ReviewKit

A portable iOS review prompting system that pre-screens ratings to maximize App Store reviews while capturing constructive feedback from unhappy users.

**How it works:** When triggered, ReviewKit shows a custom star-rating sheet. Users who select 4-5 stars are directed to the native App Store review prompt. Users who select 1-3 stars are redirected to a feedback email instead. Both paths end with a thank-you confirmation.

## Requirements

- iOS 16.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add ReviewKit to your project via Xcode or your `Package.swift`:

**Xcode:** File > Add Package Dependencies > enter the repo URL:
```
https://github.com/seannam/ReviewKit.git
```

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/seannam/ReviewKit.git", from: "1.0.0")
]
```

**XcodeGen (`project.yml`):**
```yaml
packages:
  ReviewKit:
    url: https://github.com/seannam/ReviewKit.git
    from: 1.0.0

targets:
  MyApp:
    dependencies:
      - package: ReviewKit
```

After adding the dependency, run `xcodegen generate` if using XcodeGen.

## Integration Guide

Integration touches 4 files in your app. Total: ~30 lines of code.

### Step 1: Configure at app launch

In your `@main` App struct, configure ReviewKit with your app's details and register eligibility hooks.

```swift
import ReviewKit
import SwiftUI

@main
struct MyApp: App {
    init() {
        configureReviewKit()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureReviewKit() {
        // 1. Basic configuration (only appName and feedbackEmail are required)
        ReviewManager.shared.configure(ReviewKitConfig(
            appName: "My App",
            feedbackEmail: "support@example.com"
        ))

        // 2. Register eligibility hooks (optional but recommended)
        //    These closures let ReviewKit check your game state without
        //    knowing anything about your data model. ALL hooks must return
        //    true for the automatic prompt to fire.

        ReviewManager.shared.addEligibilityHook(name: "tutorialDone") {
            GameManager.shared.tutorialCompleted
        }

        ReviewManager.shared.addEligibilityHook(name: "hasProgress") {
            GameManager.shared.playerLevel >= 5
        }

        // 3. React to review outcomes (optional)
        ReviewManager.shared.onReviewComplete { outcome in
            switch outcome {
            case .rated(let stars):
                print("User rated \(stars) stars")
                // e.g., grant a reward, log to analytics
            case .sentFeedback:
                print("User sent feedback")
            case .dismissedAtRating, .dismissedAtFeedback:
                break
            }
        }
    }
}
```

### Step 2: Present the review sheet

In your root view, add a sheet bound to `ReviewManager.shared.showPrompt`.

```swift
import ReviewKit
import SwiftUI

struct ContentView: View {
    @StateObject private var reviewManager = ReviewManager.shared

    var body: some View {
        MainView()
            .sheet(isPresented: $reviewManager.showPrompt) {
                ReviewPromptView()
            }
    }
}
```

### Step 3: Report engagement events

Call `reportEngagement()` at key moments in your app. ReviewKit tracks these internally and decides when thresholds are met. You do not need to check eligibility yourself.

```swift
import ReviewKit

// On each app session start (e.g., in your game manager or app delegate)
ReviewManager.shared.reportEngagement(.sessionStart)

// After significant achievements
ReviewManager.shared.reportEngagement(.milestone)

// After prestige/reset (idle games)
ReviewManager.shared.reportEngagement(.prestige)

// After a purchase
ReviewManager.shared.reportEngagement(.purchase)

// After any significant positive action
ReviewManager.shared.reportEngagement(.significantAction)
```

**Where to place these calls depends on your architecture.** Common locations:
- `.sessionStart` -- in your login tracking, `scenePhase` handler, or game manager init
- `.milestone` -- after unlocking an achievement or reaching a level
- `.prestige` -- after a prestige/reset cycle
- `.purchase` -- after a successful IAP

### Step 4: Add "Rate This App" to Settings

Add a button anywhere in your app (typically Settings) that triggers the review flow manually. This bypasses all eligibility checks and hooks.

```swift
import ReviewKit

Button("Rate This App") {
    ReviewManager.shared.triggerManualPrompt()
}
```

That's it. ReviewKit handles everything else: the star rating UI, routing logic, feedback email composition, native review prompt, thank-you screen, persistence, and rate limiting.

## Configuration Reference

All `ReviewKitConfig` properties with their defaults:

| Property | Type | Default | Description |
|---|---|---|---|
| `appName` | `String` | (required) | Shown in prompt title and thank-you message |
| `feedbackEmail` | `String` | (required) | Email address for low-rating feedback |
| `feedbackEmailSubject` | `String` | `"\(appName) - Feedback"` | Pre-filled email subject line |
| `accentColor` | `Color` | `.yellow` | Stars, buttons, icons |
| `backgroundColor` | `Color` | `.systemBackground` | Sheet background |
| `cardColor` | `Color` | `.secondarySystemBackground` | Card backgrounds |
| `textPrimaryColor` | `Color` | `.primary` | Titles and headings |
| `textSecondaryColor` | `Color` | `.secondary` | Subtitles and secondary text |
| `positiveThreshold` | `Int` | `4` | Minimum stars to route to App Store review |
| `minSessionsBeforePrompt` | `Int` | `5` | Sessions before first auto-prompt |
| `minDaysSinceInstall` | `Int` | `2` | Days after install before first auto-prompt |
| `daysBetweenPrompts` | `Int` | `7` | Cooldown between auto-prompts |
| `maxAutoPrompts` | `Int` | `3` | Maximum automatic prompts (lifetime) |
| `userDefaultsSuitePrefix` | `String` | `"reviewkit"` | UserDefaults key prefix (change per app to avoid collisions if needed) |

### Theming example

```swift
ReviewManager.shared.configure(ReviewKitConfig(
    appName: "Sushi Tycoon",
    feedbackEmail: "support+sushi@example.com",
    accentColor: .orange,
    backgroundColor: Color(hex: "#1A1A2E"),
    cardColor: Color(hex: "#16213E"),
    textPrimaryColor: .white,
    textSecondaryColor: .white.opacity(0.7)
))
```

## Hook System

Hooks let ReviewKit make decisions based on your app's state without importing any of your code.

### Eligibility Hooks

Gate the automatic prompt on arbitrary conditions. ALL registered hooks must return `true` (AND logic). The manual `triggerManualPrompt()` bypasses these entirely.

```swift
// Register
ReviewManager.shared.addEligibilityHook(name: "hasPlayed10Min") {
    GameManager.shared.totalPlayTime > 600
}

// Remove (e.g., if conditions change)
ReviewManager.shared.removeEligibilityHook(name: "hasPlayed10Min")
```

### Event Hooks

Observe engagement events for analytics or side effects.

```swift
ReviewManager.shared.onEngagementEvent { event in
    Analytics.track("reviewkit_engagement", properties: ["event": "\(event)"])
}
```

### Completion Hooks

React to how the user completed the review flow.

```swift
ReviewManager.shared.onReviewComplete { outcome in
    switch outcome {
    case .rated(let stars):
        // User selected 4-5 stars and was shown the native review prompt
        CurrencyManager.shared.grant(gems: 50)
    case .sentFeedback:
        // User selected 1-3 stars and tapped "Send Feedback"
        CurrencyManager.shared.grant(gems: 25)
    case .dismissedAtRating:
        // User tapped "Not Now" on the star rating screen
        break
    case .dismissedAtFeedback:
        // User tapped "Not Now" on the feedback screen
        break
    }
}
```

## How Auto-Prompting Works

When `reportEngagement()` is called, ReviewKit checks all of the following. The prompt only shows if every condition is met:

1. User has not already rated (`hasRated == false`)
2. Not already prompted this session
3. Session count >= `minSessionsBeforePrompt` (default: 5)
4. Days since install >= `minDaysSinceInstall` (default: 2)
5. Days since last prompt >= `daysBetweenPrompts` (default: 7)
6. Total prompts shown < `maxAutoPrompts` (default: 3)
7. All registered eligibility hooks return `true`

`triggerManualPrompt()` (Settings button) bypasses all of the above.

## Persistence

ReviewKit stores its state in `UserDefaults.standard` with keys prefixed by `userDefaultsSuitePrefix` (default: `"reviewkit"`). Tracked values:

- `reviewkit_hasRated` -- whether the user has submitted a positive rating
- `reviewkit_lastPromptDate` -- date of the last auto-prompt
- `reviewkit_promptsShown` -- total auto-prompts shown
- `reviewkit_firstLaunchDate` -- first time `configure()` was called
- `reviewkit_sessionCount` -- incremented on each `.sessionStart` event

No data is stored in your app's game state, save files, or any external service.

## User Flow

```
reportEngagement() or triggerManualPrompt()
        |
        v
  +-----------+
  | Star Rating|  "Enjoying MyApp?"
  | 1 2 3 4 5 |  [Submit] [Not Now]
  +-----------+
    |         |
    |         +-- 4-5 stars --> Native SKStoreReviewController
    |                           --> Thank You screen (auto-dismiss 2.5s)
    |
    +-- 1-3 stars --> Feedback Redirect
                      "We'd Love Your Feedback"
                      [Send Feedback] [Not Now]
                        |
                        +--> Opens mailto: with device info
                             --> Thank You screen (auto-dismiss 2.5s)
```
