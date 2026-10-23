//
//  ShareCardSheet.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// The share sheet for a card (v1 plan, Phase 31): the format (Story or Square), a preview of the exact
/// image, and Share, which opens the system share sheet with the image and a short text
/// (`ActivitySharing`). The image follows the app's appearance and language. The preview reads the
/// shared text to VoiceOver, since the image itself can't be read.
struct ShareCardSheet: View {

    let content: ShareCardContent

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var format = ShareCardFormat.story
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.stackDefault) {
                Picker("Format", selection: $format) {
                    ForEach(ShareCardFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(Haptics.selection, trigger: format)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let image {
                    Button {
                        ActivitySharing.present(image: image, text: content.message,
                                                title: String(localized: content.title))
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.stackDefault)
            .background(Color(.sheetBackground))
            .navigationTitle(Text(content.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color(.gold))
                }
            }
        }
        .task(id: RenderKey(format: format, colorScheme: colorScheme)) {
            image = ShareCardRenderer.image(for: content, format: format, colorScheme: colorScheme, locale: locale)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color(.hairline), lineWidth: 1)
                }
                .accessibilityLabel(Text(verbatim: content.message))
                .motionTransition(.opacity)
        } else {
            ProgressView()
        }
    }

    /// The render depends on these two only; the content and language don't change while it's open.
    private struct RenderKey: Equatable {
        let format: ShareCardFormat
        let colorScheme: ColorScheme
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    ShareCardSheet(content: .achievement(AchievementCatalog.achievement(.saver), .gold))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ShareCardSheet(content: .achievement(AchievementCatalog.achievement(.inTheBlack), .bronze))
        .preferredColorScheme(.dark)
}
#endif
