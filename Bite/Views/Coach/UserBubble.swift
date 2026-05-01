import SwiftUI

struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 20, bottomLeading: 20, bottomTrailing: 20, topTrailing: 6)
                    )
                    .fill(Color.biteRed)
                )
                .shadow(color: .biteRed.opacity(0.2), radius: 8, x: 0, y: 2)
        }
    }
}

struct AssistantText: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.biteInk)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 40)
        }
    }
}
