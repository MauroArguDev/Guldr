//
//  LockOverlayWindow.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import SwiftUI
import UIKit

/// A window above the app's for the lock screen and the privacy cover (ADR 011). A view inside the app
/// would sit under any sheet, alert or menu the app is presenting; a window at the alert level covers
/// all of them, and the app keeps its state underneath. Hidden while it has nothing to show, so it never
/// takes a touch from the app.
///
/// The cover is a blurred picture of the app, taken the moment it's shown. A material in this window
/// can't blur another window's content in the app switcher's snapshot: it rendered as a flat color.
final class LockOverlayWindow {

    /// Creates the window once the app's scene is known. The window shows `AppLock`'s state by itself.
    func install(in scene: UIWindowScene, lock: AppLock) {
        guard window == nil else { return }
        self.lock = lock
        let host = UIHostingController(rootView: LockOverlay(snapshot: snapshot).environment(lock))
        host.view.backgroundColor = .clear
        // VoiceOver stays in this window while it's up, instead of reading the app under it.
        host.view.accessibilityViewIsModal = true
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.rootViewController = host
        self.window = window
        setVisible(lock.isOverlayVisible)
    }

    func setVisible(_ isVisible: Bool) {
        guard let window, window.isHidden == isVisible else { return }
        if isVisible {
            // Taken before anything changes, so the picture is the app as it was, sheets included.
            if lock?.isLocked == false { snapshot.image = picture(of: window.windowScene, excluding: window) }
            // A keyboard has its own, higher window; closing it keeps typed text out of sight.
            window.windowScene?.windows.forEach { $0.endEditing(true) }
            window.isHidden = false
        } else {
            window.isHidden = true
            snapshot.image = nil
        }
    }

    // MARK: - Private

    private var window: UIWindow?
    private weak var lock: AppLock?
    private let snapshot = CoverSnapshot()

    /// The scene's visible windows below this one, drawn bottom to top into one image.
    private func picture(of scene: UIWindowScene?, excluding overlay: UIWindow) -> UIImage? {
        guard let scene else { return nil }
        let windows = scene.windows
            .filter { $0 !== overlay && !$0.isHidden }
            .sorted { $0.windowLevel < $1.windowLevel }
        guard let bounds = windows.first?.bounds else { return nil }
        return UIGraphicsImageRenderer(bounds: bounds).image { _ in
            for window in windows {
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
        }
    }
}

/// The picture the cover blurs, set by `LockOverlayWindow` when the cover appears.
@Observable
private final class CoverSnapshot {
    var image: UIImage?
}

/// What the overlay window draws: the lock screen while locked, otherwise the blurred cover while the
/// app isn't in front, otherwise nothing.
private struct LockOverlay: View {

    let snapshot: CoverSnapshot

    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            if lock.isLocked {
                LockView()
                    .motionTransition(.opacity)
            } else if lock.showsCover {
                cover
            }
        }
        .motion(.standard, value: lock.isLocked)
    }

    /// The app blurred enough that no amount reads but the screen stays recognizable in the switcher
    /// (author's call, 2026-10-21). Without a picture, the background color alone.
    private var cover: some View {
        ZStack {
            Color(.appBackground)
            if let image = snapshot.image {
                Image(uiImage: image)
                    .resizable()
                    .blur(radius: 28, opaque: true)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Hands over the `UIWindowScene` a SwiftUI view is in, once it's in a window.
struct WindowSceneReader: UIViewRepresentable {

    let onScene: (UIWindowScene) -> Void

    func makeUIView(context: Context) -> SceneView {
        let view = SceneView()
        view.onScene = onScene
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SceneView, context: Context) {}

    final class SceneView: UIView {
        var onScene: ((UIWindowScene) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onScene?(scene) }
        }
    }
}
