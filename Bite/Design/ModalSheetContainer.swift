import SwiftUI

/// Reusable shell for every V2 modal sheet: rounded-top white surface, grab
/// handle, header (left spacer / centered title / round close), scrollable
/// content slot. Drag-to-dismiss snaps closed past 30% of the sheet height
/// or velocity > 600 pt/s.
struct ModalSheetContainer<Content: View>: View {
    let title: String
    let onClose: () -> Void
    let content: Content

    @State private var dragOffset: CGFloat = 0

    init(
        title: String,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            grabHandle
            header
            content
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Color.white)
            .shadow(color: .black.opacity(0.16), radius: 30, x: 0, y: -6)
        }
        .offset(y: dragOffset)
        .gesture(dragGesture)
    }

    private var grabHandle: some View {
        Capsule()
            .fill(Color.black.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.biteInk)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInkMuted)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                let velocity = value.velocity.height
                let height = value.translation.height
                let threshold: CGFloat = 180
                if velocity > 600 || height > threshold {
                    onClose()
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    dragOffset = 0
                }
            }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
            .blur(radius: 8)
        VStack {
            Spacer()
            ModalSheetContainer(title: "Hydration", onClose: {}) {
                VStack(spacing: 16) {
                    Text("Sheet content goes here.")
                        .padding()
                }
                .frame(height: 400)
            }
        }
    }
}
