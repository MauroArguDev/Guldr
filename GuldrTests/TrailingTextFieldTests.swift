//
//  TrailingTextFieldTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 6/11/26.
//

import Testing
import UIKit
@testable import Guldr

/// The add sheet's description field: where its text sits as the user types.
struct TrailingTextFieldTests {

    @Test func aTrailingSpaceMovesTheDescriptionLeft() {
        let field = TrailingTextField()
        field.font = .systemFont(ofSize: 16)
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 46)

        field.text = "Tacos"
        let word = field.editingRect(forBounds: bounds)
        field.text = "Tacos "
        let space = field.editingRect(forBounds: bounds)

        #expect(word.maxX == bounds.maxX)
        #expect(space.maxX == bounds.maxX)
        #expect(space.minX < word.minX)
    }

    @Test func aLongDescriptionFillsTheField() {
        let field = TrailingTextField()
        field.font = .systemFont(ofSize: 16)
        field.text = String(repeating: "Tacos ", count: 40)
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 46)
        #expect(field.editingRect(forBounds: bounds).width == bounds.width)
    }
}
