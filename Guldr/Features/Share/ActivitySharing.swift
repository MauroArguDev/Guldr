//
//  ActivitySharing.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import LinkPresentation
import UIKit

/// Shares a card through the system share sheet (`UIActivityViewController`) instead of `ShareLink`,
/// because each destination needs to receive something different. Instagram's share extension accepts
/// images only: handed raw PNG data, or a text next to the image, it says "Content currently
/// unavailable". So the image goes as a `UIImage`, and the text goes to every destination except Instagram.
enum ActivitySharing {

    static func present(image: UIImage, text: String, title: String) {
        let items: [Any] = [ImageItem(image: image, title: title), TextItem(text: text)]
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        topViewController()?.present(controller, animated: true)
    }

    /// The view controller on top of the app's key window: the share sheet over the card sheet.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// The card's image, with its title and thumbnail for the share sheet's header.
private final class ImageItem: NSObject, UIActivityItemSource {

    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

/// The short text that goes with the image, left out for Instagram, which rejects it.
private final class TextItem: NSObject, UIActivityItemSource {

    let text: String

    init(text: String) {
        self.text = text
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Instagram's extensions are "com.burbn.instagram.shareextension" and similar.
        if let activityType, activityType.rawValue.localizedCaseInsensitiveContains("instagram") { return nil }
        return text
    }
}
