import SwiftUI

/// Shown when the user selects a low star rating. Encourages them
/// to send feedback via email instead of leaving a negative App Store review.
struct FeedbackRedirectView: View {
    let onSendFeedback: () -> Void
    let onDismiss: () -> Void

    private var config: ReviewKitConfig { ReviewManager.shared.config }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.open.fill")
                .font(.system(size: 56))
                .foregroundColor(config.accentColor)

            Text("We'd Love Your Feedback")
                .font(.title2.bold())
                .foregroundColor(config.textPrimaryColor)
                .multilineTextAlignment(.center)

            Text("Your feedback helps us make \(config.appName) better for everyone.")
                .font(.subheadline)
                .foregroundColor(config.textSecondaryColor)
                .multilineTextAlignment(.center)

            Button {
                onSendFeedback()
            } label: {
                Text("Send Feedback")
                    .font(.headline)
                    .foregroundColor(config.backgroundColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(config.accentColor)
                    .cornerRadius(14)
            }

            Button {
                onDismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundColor(config.textSecondaryColor)
            }

            Spacer()
        }
        .padding(24)
    }
}
