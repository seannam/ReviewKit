import SwiftUI
import UIKit

// MARK: - Configuration

/// Configuration for ReviewKit. Provide app-specific values at launch.
/// All fields have sensible defaults -- only `appName` and `feedbackEmail` are required.
public struct ReviewKitConfig {
    public let appName: String
    public let feedbackEmail: String
    public var feedbackEmailSubject: String
    public var accentColor: Color
    public var backgroundColor: Color
    public var cardColor: Color
    public var textPrimaryColor: Color
    public var textSecondaryColor: Color
    public var positiveThreshold: Int
    public var minSessionsBeforePrompt: Int
    public var minDaysSinceInstall: Int
    public var daysBetweenPrompts: Int
    public var maxAutoPrompts: Int
    public var userDefaultsSuitePrefix: String

    public init(
        appName: String,
        feedbackEmail: String,
        feedbackEmailSubject: String? = nil,
        accentColor: Color = .yellow,
        backgroundColor: Color = Color(uiColor: .systemBackground),
        cardColor: Color = Color(uiColor: .secondarySystemBackground),
        textPrimaryColor: Color = .primary,
        textSecondaryColor: Color = .secondary,
        positiveThreshold: Int = 5,
        minSessionsBeforePrompt: Int = 5,
        minDaysSinceInstall: Int = 2,
        daysBetweenPrompts: Int = 7,
        maxAutoPrompts: Int = 3,
        userDefaultsSuitePrefix: String = "reviewkit"
    ) {
        self.appName = appName
        self.feedbackEmail = feedbackEmail
        self.feedbackEmailSubject = feedbackEmailSubject ?? "\(appName) - Feedback"
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.cardColor = cardColor
        self.textPrimaryColor = textPrimaryColor
        self.textSecondaryColor = textSecondaryColor
        self.positiveThreshold = positiveThreshold
        self.minSessionsBeforePrompt = minSessionsBeforePrompt
        self.minDaysSinceInstall = minDaysSinceInstall
        self.daysBetweenPrompts = daysBetweenPrompts
        self.maxAutoPrompts = maxAutoPrompts
        self.userDefaultsSuitePrefix = userDefaultsSuitePrefix
    }
}

// MARK: - Engagement Events

/// Events the host app reports to ReviewKit to signal user engagement.
public enum EngagementEvent {
    case sessionStart
    case milestone
    case prestige
    case purchase
    case significantAction
}

// MARK: - Review Outcome

/// The result of a review flow, reported to completion hooks.
public enum ReviewOutcome {
    case rated(stars: Int)
    case sentFeedback
    case dismissedAtRating
    case dismissedAtFeedback
}

// MARK: - Hook Types

/// Returns `true` if the host app considers the user eligible for a review prompt.
/// ALL registered eligibility hooks must return `true` for the prompt to show.
public typealias EligibilityHook = @MainActor () -> Bool

/// Called whenever an engagement event fires.
public typealias EventHook = @MainActor (EngagementEvent) -> Void

/// Called when the review flow completes with an outcome.
public typealias CompletionHook = @MainActor (ReviewOutcome) -> Void
