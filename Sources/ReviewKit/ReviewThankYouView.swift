import SwiftUI

/// Thank-you confirmation shown after both the review and feedback paths.
/// Auto-dismisses after 2.5 seconds or on tap.
struct ReviewThankYouView: View {
    let didRate: Bool
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    private var config: ReviewKitConfig { ReviewManager.shared.config }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: didRate ? "heart.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(config.accentColor)
                .scaleEffect(scale)

            Text("Thank You!")
                .font(.title.bold())
                .foregroundColor(config.textPrimaryColor)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(config.textSecondaryColor)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onDismiss()
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }

    private var subtitle: String {
        if didRate {
            return "Your review helps other players discover \(config.appName)!"
        } else {
            return "We appreciate your feedback and will use it to improve!"
        }
    }
}
