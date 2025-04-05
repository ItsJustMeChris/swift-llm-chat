import SwiftUI

struct IconButton: View {
    let systemName: String
    var action: () -> Void = {}
    var iconColor: Color = .gray
    var backgroundColor: Color = Color(.sRGB, white: 0.2, opacity: 1)

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .padding(8)
                .background(backgroundColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct FlatIcon: View {
    let systemName: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .buttonStyle(.plain)
    }
}
