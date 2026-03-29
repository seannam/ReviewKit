import SwiftUI

/// The main review prompt view that manages the full flow:
/// Dynamic star rating with contextual button labels and messaging per star level.
/// Only 5-star users are routed to the native App Store review.
public struct ReviewPromptView: View {
    @Environment(\.dismiss) private var dismiss

    enum FlowState {
        case rating
        case thankYou(didRate: Bool)
    }

    @State private var flowState: FlowState = .rating
    @State private var selectedStars: Int = 0

    private var config: ReviewKitConfig { ReviewManager.shared.config }

    public init() {}

    public var body: some View {
        ZStack {
            config.backgroundColor.ignoresSafeArea()

            switch flowState {
            case .rating:
                ratingView
            case .thankYou(let didRate):
                ReviewThankYouView(didRate: didRate) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Rating View

    private var ratingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Enjoying \(config.appName)?")
                .font(.title2.bold())
                .foregroundColor(config.textPrimaryColor)
                .multilineTextAlignment(.center)

            Text(dynamicSubtitle)
                .font(.subheadline)
                .foregroundColor(config.textSecondaryColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: selectedStars)

            // Star rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedStars = star
                        }
                    } label: {
                        Image(systemName: star <= selectedStars ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(star <= selectedStars ? config.accentColor : config.textSecondaryColor.opacity(0.5))
                            .scaleEffect(star <= selectedStars ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            // Dynamic action button
            Button {
                handleSubmit()
            } label: {
                Text(dynamicButtonLabel)
                    .font(.headline)
                    .foregroundColor(config.backgroundColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedStars > 0 ? config.accentColor : config.textSecondaryColor.opacity(0.3))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: selectedStars)
            }
            .disabled(selectedStars == 0)

            // Not now
            Button {
                ReviewManager.shared.completeFlow(.dismissedAtRating)
                dismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundColor(config.textSecondaryColor)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Dynamic Content

    private var dynamicSubtitle: String {
        switch selectedStars {
        case 0:
            return "Tap a star to rate your experience"
        case 1:
            return "We're sorry to hear that. Let us help."
        case 2:
            return "We'd love to know how we can do better."
        case 3:
            return "Thanks! What could we improve?"
        case 4:
            return "So close! What would make it 5 stars?"
        default:
            return "Awesome! We'd love a rating and review!"
        }
    }

    private var dynamicButtonLabel: String {
        switch selectedStars {
        case 0:
            return "Select a Rating"
        case 1:
            return "Contact Support"
        case 2, 3:
            return "Send Feedback"
        case 4:
            return "Tell Us More"
        default:
            return "Rate & Review"
        }
    }

    // MARK: - Actions

    private func handleSubmit() {
        switch selectedStars {
        case 1:
            ReviewManager.shared.openFeedbackEmail(
                subject: "\(config.appName) - Support Request"
            )
            ReviewManager.shared.completeFlow(.sentFeedback)
            withAnimation { flowState = .thankYou(didRate: false) }
        case 2, 3:
            ReviewManager.shared.openFeedbackEmail()
            ReviewManager.shared.completeFlow(.sentFeedback)
            withAnimation { flowState = .thankYou(didRate: false) }
        case 4:
            ReviewManager.shared.openFeedbackEmail(
                subject: "\(config.appName) - How Can We Make It 5 Stars?"
            )
            ReviewManager.shared.completeFlow(.sentFeedback)
            withAnimation { flowState = .thankYou(didRate: false) }
        default:
            // 5 stars
            ReviewManager.shared.recordRated()
            ReviewManager.shared.completeFlow(.rated(stars: selectedStars))
            withAnimation { flowState = .thankYou(didRate: true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ReviewManager.shared.requestNativeReview()
            }
        }
    }
}
