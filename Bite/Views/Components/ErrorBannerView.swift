import SwiftUI

struct ErrorBannerView: View {
    @Binding var isPresented: Bool
    let message: String

    var body: some View {
        if isPresented {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.biteRed, Color.biteOrange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .biteRed.opacity(0.3), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var show = true
    VStack {
        ErrorBannerView(
            isPresented: $show,
            message: "Connessione non disponibile. Riprova."
        )
        Spacer()
    }
}
