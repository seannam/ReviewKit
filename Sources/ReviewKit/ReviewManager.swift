import Foundation
import StoreKit
import UIKit

/// Self-contained review prompt manager. Owns its persistence via UserDefaults
/// and has zero dependencies on any app-specific code.
@MainActor
public class ReviewManager: ObservableObject {
    public static let shared = ReviewManager()

    // MARK: - Published State

    @Published public var showPrompt: Bool = false
    @Published public private(set) var config: ReviewKitConfig

    // MARK: - Hook Storage

    private var eligibilityHooks: [String: EligibilityHook] = [:]
    private var eventHooks: [EventHook] = []
    private var completionHooks: [CompletionHook] = []

    // MARK: - Session State (not persisted)

    private var hasPromptedThisSession = false

    // MARK: - Initialization

    private init() {
        self.config = ReviewKitConfig(appName: "", feedbackEmail: "")
    }

    // MARK: - Configuration

    public func configure(_ config: ReviewKitConfig) {
        self.config = config

        // Record first launch date if not already set
        if firstLaunchDate == nil {
            firstLaunchDate = Date()
        }
    }

    // MARK: - Hook Registration

    public func addEligibilityHook(name: String, _ hook: @escaping EligibilityHook) {
        eligibilityHooks[name] = hook
    }

    public func removeEligibilityHook(name: String) {
        eligibilityHooks.removeValue(forKey: name)
    }

    public func onEngagementEvent(_ hook: @escaping EventHook) {
        eventHooks.append(hook)
    }

    public func onReviewComplete(_ hook: @escaping CompletionHook) {
        completionHooks.append(hook)
    }

    // MARK: - Engagement Reporting

    public func reportEngagement(_ event: EngagementEvent) {
        if case .sessionStart = event {
            sessionCount += 1
        }

        // Fire event hooks
        for hook in eventHooks {
            hook(event)
        }

        // Check if we should show the prompt
        if shouldPrompt() {
            hasPromptedThisSession = true
            recordPromptShown()
            showPrompt = true
        }
    }

    // MARK: - Eligibility

    public func shouldPrompt() -> Bool {
        // Internal threshold checks
        guard !hasRated else { return false }
        guard !hasPromptedThisSession else { return false }
        guard sessionCount >= config.minSessionsBeforePrompt else { return false }
        guard promptsShown < config.maxAutoPrompts else { return false }

        // Days since install check
        if let firstLaunch = firstLaunchDate {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
            guard daysSinceInstall >= config.minDaysSinceInstall else { return false }
        }

        // Days since last prompt check
        if let lastPrompt = lastPromptDate {
            let daysSincePrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            guard daysSincePrompt >= config.daysBetweenPrompts else { return false }
        }

        // All eligibility hooks must return true
        for (_, hook) in eligibilityHooks {
            guard hook() else { return false }
        }

        return true
    }

    // MARK: - State Updates

    func recordPromptShown() {
        promptsShown += 1
        lastPromptDate = Date()
    }

    func recordRated() {
        hasRated = true
    }

    func completeFlow(_ outcome: ReviewOutcome) {
        for hook in completionHooks {
            hook(outcome)
        }
    }

    // MARK: - Actions

    func requestNativeReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        SKStoreReviewController.requestReview(in: scene)
    }

    func openFeedbackEmail(subject customSubject: String? = nil) {
        let subject = customSubject ?? config.feedbackEmailSubject
        let deviceInfo = buildDeviceInfo()
        let body = """
        Please share your feedback below:

        ---



        ---
        Device Information (please do not delete):
        \(deviceInfo)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(config.feedbackEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    /// For the Settings "Rate This App" button. Bypasses all eligibility checks and hooks.
    public func triggerManualPrompt() {
        showPrompt = true
    }

    // MARK: - Device Info

    private func buildDeviceInfo() -> String {
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }

        let idiom = device.userInterfaceIdiom == .pad ? "iPad" : "iPhone"

        return """
        App: \(config.appName) \(version) (\(build))
        Device: \(idiom) (\(identifier))
        iOS: \(device.systemVersion)
        """
    }

    // MARK: - UserDefaults Persistence

    private func key(_ name: String) -> String {
        "\(config.userDefaultsSuitePrefix)_\(name)"
    }

    private var hasRated: Bool {
        get { UserDefaults.standard.bool(forKey: key("hasRated")) }
        set { UserDefaults.standard.set(newValue, forKey: key("hasRated")) }
    }

    private var lastPromptDate: Date? {
        get { UserDefaults.standard.object(forKey: key("lastPromptDate")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key("lastPromptDate")) }
    }

    private var promptsShown: Int {
        get { UserDefaults.standard.integer(forKey: key("promptsShown")) }
        set { UserDefaults.standard.set(newValue, forKey: key("promptsShown")) }
    }

    private var firstLaunchDate: Date? {
        get { UserDefaults.standard.object(forKey: key("firstLaunchDate")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key("firstLaunchDate")) }
    }

    private var sessionCount: Int {
        get { UserDefaults.standard.integer(forKey: key("sessionCount")) }
        set { UserDefaults.standard.set(newValue, forKey: key("sessionCount")) }
    }
}
