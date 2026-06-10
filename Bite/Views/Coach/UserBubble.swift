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
            Text(attributedText)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.biteInk)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 40)
        }
    }

    private var attributedText: AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

struct ResearchCitationStrip: View {
    let citations: [CoachChatViewModel.ResearchCitation]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.biteInkFaint)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(citations.prefix(6)) { citation in
                        Link(destination: citation.url) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(citation.source)
                                    .font(.system(size: 10.5, weight: .heavy))
                                    .foregroundStyle(.biteRed)
                                    .lineLimit(1)
                                Text(citation.title)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(.biteInk)
                                    .lineLimit(2)
                                if let journal = citation.journal {
                                    Text(journal)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.biteInkFaint)
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                            .frame(width: 190, height: 96, alignment: .topLeading)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
            }
        }
    }
}
