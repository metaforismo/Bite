import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image("BiteLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 18))

                Text("Bite")
                    .font(.largeTitle.bold())

                Text("Il tuo diario alimentare intelligente.\nSemplice, veloce, preciso.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Informazioni")
        .navigationBarTitleDisplayMode(.inline)
    }
}
