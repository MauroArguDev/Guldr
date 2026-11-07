//
//  HorizontalPan.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 6/11/26.
//

import SwiftUI
import UIKit

/// A horizontal drag on content inside a vertical `ScrollView`. SwiftUI's `DragGesture` either blocks the
/// scroll view or runs along with it; a UIKit pan can decide from the first movement, so a vertical drag
/// still scrolls and a horizontal one only reports here.
struct HorizontalPan: UIGestureRecognizerRepresentable {

    /// The finger's horizontal distance from where it started.
    let onChanged: (CGFloat) -> Void
    /// The final distance and speed in points per second, both zero when the system cancels the pan.
    let onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let view = recognizer.view
        switch recognizer.state {
        case .changed:
            onChanged(recognizer.translation(in: view).x)
        case .ended:
            onEnded(recognizer.translation(in: view).x, recognizer.velocity(in: view).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        /// The scroll view waits for this pan to decide, so the two never start together.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}
