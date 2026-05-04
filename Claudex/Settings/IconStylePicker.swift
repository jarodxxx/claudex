import SwiftUI

/// Visual grid picker for `IconStyle`. Each tile shows a live preview of how
/// the icon would look at 65% utilization in the menu bar.
struct IconStylePicker: View {
    @Binding var selection: IconStyle

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(IconStyle.allCases) { style in
                IconStyleTile(
                    style: style,
                    isSelected: style == selection
                ) {
                    selection = style
                    AppSettings.iconStyle = style
                    NotificationCenter.default.post(name: .claudexIconStyleChanged, object: nil)
                }
            }
        }
    }
}

private struct IconStyleTile: View {
    let style: IconStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                IconPreview(style: style)
                    .frame(height: 44)
                HStack(spacing: 4) {
                    Text(style.displayName)
                        .font(.caption)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IconPreview: View {
    let style: IconStyle

    /// Cycles through the three colored zones so each tile shows what the
    /// icon looks like at low (35%), medium (65%), and high (95%) usage.
    private static let previewSamples = [35, 65, 95]
    @State private var sampleIndex = 1

    var body: some View {
        VStack(spacing: 4) {
            if let nsImage = StatusBarIcon.image(
                style: style,
                percent: Self.previewSamples[sampleIndex],
                status: .ok
            ) {
                Image(nsImage: nsImage)
                    .renderingMode(.original) // keep colors
            } else {
                Text("?")
            }
            HStack(spacing: 4) {
                ForEach(0..<Self.previewSamples.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == sampleIndex ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .onAppear {
            // Auto-rotate the sample every 1.5s so the user sees the 3 colors.
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { @MainActor in
                    sampleIndex = (sampleIndex + 1) % Self.previewSamples.count
                }
            }
        }
    }
}
