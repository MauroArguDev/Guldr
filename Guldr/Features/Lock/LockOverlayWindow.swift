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
final class LockOverlayWindow {

    /// Creates the window once the app's scene is known. The window shows `AppLock`'s state by itself.
    func install(in scene: UIWindowScene, lock: AppLock) {
        guard window == nil else { return }
        let host = UIHostingController(rootView: LockOverlay().environment(lock))
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
            // A keyboard has its own, higher window; closing it keeps typed text out of sight.
            window.windowScene?.windows.forEach { $0.endEditing(true) }
            window.isHidden = false
        } else {
            window.isHidden = true
        }
    }

    // MARK: - Private

    private var window: UIWindow?
}

/// What the overlay window draws: the lock screen while locked, otherwise the blurred cover while the
/// app isn't in front, otherwise nothing.
private struct LockOverlay: View {

    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            if lock.isLocked {
                LockView()
                    .motionTransition(.opacity)
            } else if lock.showsCover {
                // A thick material: the app stays recognizable in the switcher, but no amount reads.
                Rectangle()
                    .fill(.thickMaterial)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .motion(.standard, value: lock.isLocked)
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
