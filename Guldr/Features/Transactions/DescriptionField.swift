//
//  DescriptionField.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 6/11/26.
//

import SwiftUI
import UIKit

/// The add sheet's description. A right-aligned text field doesn't move its text for a trailing space, so the
/// user can't tell the space bar worked, and no-break spaces don't move it either on iOS 27. SwiftUI's
/// `TextField` can't change that, so this wraps `TrailingTextField`, whose text is left-aligned but sits
/// against the trailing edge.
struct DescriptionField: UIViewRepresentable {

    @Binding var text: String
    @Binding var isFocused: Bool
    /// Shown while the description is empty.
    let prompt: String
    /// Against the trailing edge, or from the leading edge at accessibility text sizes.
    let hugsTrailingEdge: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> TrailingTextField {
        let field = TrailingTextField()
        field.font = .preferredFont(forTextStyle: .callout)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(resource: .textPrimary)
        field.tintColor = UIColor(resource: .gold)
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        // A long description scrolls inside the field instead of pushing its label away.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: TrailingTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        field.placeholder = prompt
        field.hugsTrailingEdge = hugsTrailingEdge
        // The text or the prompt may have changed, and the text's place depends on both.
        field.setNeedsLayout()
        if isFocused, !field.isFirstResponder {
            field.becomeFirstResponder()
        } else if !isFocused, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {

        var parent: DescriptionField

        init(parent: DescriptionField) {
            self.parent = parent
        }

        @objc func textDidChange(_ field: UITextField) {
            parent.text = field.text ?? ""
            field.setNeedsLayout()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            // Also runs inside `updateUIView`, where state can't change until the update ends.
            Task {
                if parent.isFocused, !textField.isFirstResponder { parent.isFocused = false }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// A left-aligned text field whose text rect is as wide as the text and ends at the trailing edge. Left-aligned
/// text keeps its trailing spaces, so each one widens the rect and moves the text left. A description too long
/// for the field fills it and scrolls as usual.
final class TrailingTextField: UITextField {

    var hugsTrailingEdge = true

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        hugging(super.textRect(forBounds: bounds))
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        hugging(super.editingRect(forBounds: bounds))
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        hugging(super.placeholderRect(forBounds: bounds))
    }

    private func hugging(_ rect: CGRect) -> CGRect {
        guard hugsTrailingEdge, let font else { return rect }
        let shown = text?.isEmpty == false ? text : placeholder
        // No-break spaces, so the measure counts trailing spaces too.
        let measured = (shown ?? "").replacingOccurrences(of: " ", with: "\u{00A0}") as NSString
        // The caret needs room past the last character.
        let width = min(ceil(measured.size(withAttributes: [.font: font]).width) + 2, rect.width)
        return CGRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height)
    }
}
