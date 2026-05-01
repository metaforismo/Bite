import SwiftUI

struct AppIconPicker: View {
    @State private var selectedIcon: String? = UIApplication.shared.alternateIconName

    private let icons: [(name: String?, displayName: String, imageName: String)] = [
        (nil, "Default", "logobite-iOS-Default-1024x1024@1x"),
        ("AppIcon-Dark", "Dark", "AppIcon-Dark"),
        ("AppIcon-ClearDark", "Clear Dark", "AppIcon-ClearDark"),
        ("AppIcon-ClearLight", "Clear Light", "AppIcon-ClearLight"),
        ("AppIcon-TintedDark", "Tinted Dark", "AppIcon-TintedDark"),
        ("AppIcon-TintedLight", "Tinted Light", "AppIcon-TintedLight"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(icons, id: \.displayName) { icon in
                Button {
                    setIcon(icon.name)
                } label: {
                    VStack(spacing: 8) {
                        Image(icon.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        selectedIcon == icon.name ? Color.biteRed : Color.clear,
                                        lineWidth: 3
                                    )
                            )

                        Text(icon.displayName)
                            .font(.caption2)
                            .foregroundStyle(selectedIcon == icon.name ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func setIcon(_ name: String?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.setAlternateIconName(name) { error in
            if error == nil {
                Task { @MainActor in
                    selectedIcon = name
                }
            }
        }
    }
}
