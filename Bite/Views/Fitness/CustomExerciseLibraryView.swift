import SwiftUI

/// Stub — replaced with categorized exercise library in B6.
struct CustomExerciseLibraryView: View {
    @Bindable var router: BiteRouter

    var body: some View {
        ModalSheetContainer(title: "Exercise library", onClose: { router.closeModal() }) {
            VStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.biteRedDeep)
                Text("Exercise library coming in B6")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
        }
    }
}
