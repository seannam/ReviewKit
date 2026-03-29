import SwiftUI

/// The main review prompt view that manages the full flow:
/// star rating -> (positive: thank you) or (negative: feedback redirect -> thank you)
public struct ReviewPromptView: View {
    @Environment(\.dismiss) private var dismiss

    enum FlowState {
        case rating
        case feedbackRedirect
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
            case .feedbackRedirect:
                FeedbackRedirectView(
                    onSendFeedback: {
                        ReviewManager.shared.openFeedbackEmail()
                        ReviewManager.shared.completeFlow(.sentFeedback)
                        withAnimation { flowState = .thankYou(didRate: false) }
                    },
                    onDismiss: {
                        ReviewManager.shared.completeFlow(.dismissedAtFeedback)
                        dismiss()
                    }
                )
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

            Text("Tap a star to rate your experience")
                .font(.subheadline)
                .foregroundColor(config.textSecondaryColor)

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

            // Submit button
            Button {
                handleSubmit()
            } label: {
                Text("Submit")
                    .font(.headline)
                    .foregroundColor(config.backgroundColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedStars > 0 ? config.accentColor : config.textSecondaryColor.opacity(0.3))
                    .cornerRadius(14)
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

    // MARK: - Actions

    private func handleSubmit() {
        if selectedStars >= config.positiveThreshold {
            ReviewManager.shared.recordRated()
            ReviewManager.shared.completeFlow(.rated(stars: selectedStars))
            withAnimation { flowState = .thankYou(didRate: true) }
            // Trigger native review after a brief delay so the thank-you is visible first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ReviewManager.shared.requestNativeReview()
            }
        } else {
            withAnimation { flowState = .feedbackRedirect }
        }
    }
}
